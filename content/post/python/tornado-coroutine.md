---
title: "Tornado Coroutine"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: []
date: 2020-04-27T15:18:20+08:00
---

[TOC]

<!--more-->

### 关系图示

```bash
 +---------------------------------+
 |IOLoop                           |
 |                                 |
 |  +----------------------------+ |
 |  |Runner                      | |
 |  |                            | |
 |  |   +----------------------+ | |
 |  |   | gen.Task             | | |
 |  |   |                      | | |
 |  |   |       +------------+ | | |
 |  |   |       |  user func | | | |
 |  |   |       +------------+ | | |
 |  |   +----------------------+ | |
 |  +----------------------------+ |
 +---------------------------------+
```

### gen.coroutine

1. 处理返回值
2. 创建runner，运行gen.Task
3. 配合gen.Task让同步的代码呈现异步的效果

<details close>
  <summary>code</summary>

```python
def coroutine(func):
    """Decorator for asynchronous generators.
    ...
    """
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        runner = None
        future = TracebackFuture()

        if 'callback' in kwargs:  # e.g. gen.Task(gen.coroutine(func), ....)
            callback = kwargs.pop('callback')
            IOLoop.current().add_future(
                future, lambda future: callback(future.result()))

        def handle_exception(typ, value, tb):
            try:
                if runner is not None and runner.handle_exception(typ, value, tb):
                    return True
            except Exception:
                typ, value, tb = sys.exc_info()
            future.set_exc_info((typ, value, tb))
            return True
        with ExceptionStackContext(handle_exception) as deactivate:
            try:
                result = func(*args, **kwargs)
            except (Return, StopIteration) as e:
                result = getattr(e, 'value', None)
            except Exception:
                deactivate()
                future.set_exc_info(sys.exc_info())
                return future
            else:
                if isinstance(result, types.GeneratorType):
                    def final_callback(value):
                        deactivate()
                        future.set_result(value)
                    runner = Runner(result, final_callback)
                    runner.run()
                    return future
            deactivate()
            future.set_result(result)
        return future
    return wrapper
```

</details>

### Runner

1. 运行gen.Task
2. 记录generator运行状态

<details close>
  <summary>code</summary>

```python
class Runner(object):
    """Internal implementation of `tornado.gen.engine`.

    Maintains information about pending callbacks and their results.

    ``final_callback`` is run after the generator exits.
    """
    def __init__(self, gen, final_callback):
        self.gen = gen            # generator, gen.Task, subclass of gen.YieldPoint
        self.final_callback = final_callback   # final_callback: 设置返回值到future
        self.yield_point = _null_yield_point  # read->True, result->None
        self.pending_callbacks = set()
        self.results = {}
        self.running = False
        self.finished = False
        self.exc_info = None
        self.had_exception = False

    def register_callback(self, key):
        """Adds ``key`` to the list of callbacks."""
        if key in self.pending_callbacks:
            raise KeyReuseError("key %r is already pending" % (key,))
        self.pending_callbacks.add(key)

    def is_ready(self, key):
        """Returns true if a result is available for ``key``."""
        if key not in self.pending_callbacks:
            raise UnknownKeyError("key %r is not pending" % (key,))
        return key in self.results

    def set_result(self, key, result):
        """Sets the result for ``key`` and attempts to resume the generator."""
        self.results[key] = result
        self.run()

    def pop_result(self, key):
        """Returns the result for ``key`` and unregisters it."""
        self.pending_callbacks.remove(key)
        return self.results.pop(key)

    def run(self):
        """Starts or resumes the generator, running until it reaches a
        yield point that is not ready.
        """
        if self.running or self.finished:
            return
        try:
            self.running = True
            while True:
                if self.exc_info is None:
                    try:
                        if not self.yield_point.is_ready():
                            return
                        next = self.yield_point.get_result()
                        self.yield_point = None
                    except Exception:
                        self.exc_info = sys.exc_info()
                try:
                    if self.exc_info is not None:
                        self.had_exception = True
                        exc_info = self.exc_info
                        self.exc_info = None
                        yielded = self.gen.throw(*exc_info)   # 标准迭代器用法
                    else:
                        yielded = self.gen.send(next)      # 迭代器用法。generator.send(None) == generator.next()
                except (StopIteration, Return) as e:
                    self.finished = True
                    self.yield_point = _null_yield_point
                    if self.pending_callbacks and not self.had_exception:
                        # If we ran cleanly without waiting on all callbacks
                        # raise an error (really more of a warning).  If we
                        # had an exception then some callbacks may have been
                        # orphaned, so skip the check in that case.
                        raise LeakedCallbackError(
                            "finished without waiting for callbacks %r" %
                            self.pending_callbacks)
                    self.final_callback(getattr(e, 'value', None))    # 回传运行结果
                    self.final_callback = None
                    return
                except Exception:
                    self.finished = True
                    self.yield_point = _null_yield_point
                    raise
                if isinstance(yielded, list):
                    yielded = Multi(yielded)
                elif isinstance(yielded, Future):
                    yielded = YieldFuture(yielded)
                if isinstance(yielded, YieldPoint):   # e.g. gen.Task
                    self.yield_point = yielded
                    try:
                        self.yield_point.start(self)  # run gen.Task
                    except Exception:
                        self.exc_info = sys.exc_info()
                else:
                    self.exc_info = (BadYieldError(
                        "yielded unknown object %r" % (yielded,)),)
        finally:
            self.running = False

    def result_callback(self, key):
        def inner(*args, **kwargs):
            if kwargs or len(args) > 1:
                result = Arguments(args, kwargs)
            elif args:
                result = args[0]
            else:
                result = None
            self.set_result(key, result)
        return wrap(inner)

    def handle_exception(self, typ, value, tb):
        if not self.running and not self.finished:
            self.exc_info = (typ, value, tb)
            self.run()
            return True
        else:
            return False
```

</details>

#### yield point

记录运行栈，运行的任务信息。

##### gen.Task

包装用户代码

<details close>
  <summary>code</summary>

```python
class Task(YieldPoint):
    """Runs a single asynchronous operation.

    Takes a function (and optional additional arguments) and runs it with
    those arguments plus a ``callback`` keyword argument.  The argument passed
    to the callback is returned as the result of the yield expression.

    A `Task` is equivalent to a `Callback`/`Wait` pair (with a unique
    key generated automatically)::

        result = yield gen.Task(func, args)

        func(args, callback=(yield gen.Callback(key)))
        result = yield gen.Wait(key)
    """
    def __init__(self, func, *args, **kwargs):
        assert "callback" not in kwargs
        self.args = args
        self.kwargs = kwargs
        self.func = func

    # 依赖注入，控制反转
    #   https://zhuanlan.zhihu.com/p/33492169
    #   https://segmentfault.com/a/1190000015173300
    def start(self, runner):
        self.runner = runner
        self.key = object()
        runner.register_callback(self.key)
        self.kwargs["callback"] = runner.result_callback(self.key)
        self.func(*self.args, **self.kwargs)

    def is_ready(self):
        return self.runner.is_ready(self.key)

    def get_result(self):
        return self.runner.pop_result(self.key)
```

</details>

### 遇到的问题

旧的代码逻辑，会在`upload_file_handel`后向redis缓存`total_answer`的值，保存的是旧的值而不是内层函数更新后的值。

<details close>
  <summary>code 去掉 加入callback相关代码后为原逻辑</summary>

```python
class AssessHandler(BaseHandler):
    def upload_result_processor(self, rid, total_answer, rst_map):    # 加入callback
        def set_redis_when_done(rid, total_answer, future_rst_map, future):
            v = future_rst_map.pop(future)
            exc_info = future.exc_info()
            if exc_info:
                log.error("rename upload for rid:{} answer:{} err".format(rid, v), {'exception': exc_info[1]})
            if not future_rst_map:
                key = 'assess_total_answer:{rid}'.format(rid=rid)
                redis_client.set_key(key, json.dumps(total_answer), 2 * 3600)

        future_rst_map = {v: k for k, v in rst_map.iteritems()}
        call_back = functools.partial(set_redis_when_done, rid, total_answer, future_rst_map)
        for future in future_rst_map.keys():
            future.add_done_callback(call_back)

    @web.asynchronous
    @gen.coroutine
    def post(self, short_id):
    	...
	upload_file_handel(total_answer, rspd, respondent,
                           functools.partial(self.upload_result_processor, rid, total_answer))   # 加入callback
	...
    

def upload_file_handel(total_answer, rspd, respondent, result_processer=None):
    upload_rst = {}             # 加入callback
    for qid, answer in total_answer.items():
        if not answer:
            continue

        question = survey_utils.get_question(qid)
        if not hasattr(question, 'custom_attr'):
            continue

        if question.custom_attr.get('disp_type') != 'upload_file':
            continue

        answers = answer.values()[0]
        option_id = answer.keys()[0]
        answer_list = [temp_answer for temp_answer in answers.split(',') if temp_answer]
        if not answer_list:
            continue

        rst = rename_upload_file(answer_list[0], total_answer, rspd, respondent, question, option_id)
	upload_rst["{} {}".format(question.oid, option_id)] = rst


    if callable(result_processer):         # 加入callback
        result_processer(upload_rst)       # 加入callback


@gen.coroutine
def rename_upload_file(answer, total_answer, rspd, respondent, question, option_id):
    new_answer = yield gen.Task(rename_upload_file_func, answer, respondent.seq, question.cid, option_id)

    if new_answer:
        rspd.set_answer(question.oid, {option_id: new_answer}, True)
        total_answer[question.oid] = {option_id: new_answer}
        # 图片、视频需审核
        if form_utils.is_video_or_image(new_answer):
            key = "{0}||{1}||{2}||{3}".format(question.project_id, question.oid, respondent.oid, new_answer)
            redis_queue_client.rpush("upload_file_check_task_queue", key)


@gen.coroutine
def rename_upload_file_func(answer, seq, q_cid, op_id):
    # 切分七牛文件名和原文件名
    orig_key, orig_fname = answer.split('|')
    name, suffiix = orig_fname.rsplit('.', 1)
    random_num = random.randint(100000, 999999)
    dest_key = u"{0}-{1}-{2}-{3}.{4}".format(seq, q_cid, name, random_num, suffiix)

    encode_uri = form_utils.get_remove_encode_uri(orig_key, dest_key, del_prefix=False)
    path = '%s%s' % ('http://rs.qiniu.com', encode_uri)
    token = form_utils.get_request_token(encode_uri)

    res = requests.post(path, headers={'Authorization': 'QBox %s' % token}, timeout=10)
    raise gen.Return("{0}|{1}".format(dest_key, orig_fname))
```

</details>

<details close>
  <summary>旧逻辑图示</summary>

```bash
+-------+ 
|IOLoop | 
+--+----+ 
   |  +-----------------------------+
   |  | gen.coroutine(post handler) |
   |  +-----+-----------------------+
   |        |
   |        +---->+--------------------+      +--------------------------------+
   |        |     | upload_file_handel +----->|gen.coroutine:rename_upload_file|
   |        |     +----------+---------+      +--------------+-----------------+
   |        |                |                               |
   |        |                |                               | generator (rename_upload_file)
   |        |                |                               |                    |
   |        |                |                               +----->+---------+   |
   |        |                |                                      |  runner |<--+
   |        |                |                                      +----+----+
   |        |                |                                           |
   |        |                |                                           |  next+-----------------------------------+
   |        |                |                                           +----->| gen.Task(rename_upload_file_func) |
   |        |                |                                           |      +---+-------------------------------+
   |        |                |                                           |          |               
   |        |                |                                           |          |start+----------------------------------------+
   |        |                |                                           |          +---> | gen.coreutine(rename_upload_file_func) |      
   |        |                |                                           |          |     +-----------+----------------------------+
   |        |                |    register callback(runner.set_result)   |          |                 |
   | <------------------------------------------------------------------------------------------------+                        +-------------------------+
   |        |                |                                           |          |                 +----------------------->| rename_upload_file_func |
   |        |                |                                           |          |                 |                        +----------+--------------+
   |        |                |                                           |          |                 |               raise Return        |
   |        |                |                                           |          |     future      |<----------------------------------+
   |        |                |                            future         | not ready|  <--------------+
   |        |                |                              ^            | <--------+
   |        |                |<-----------------------------|------------+   
   |        |                |                              |                        
   |        | future         |                   set future |            |           
   | <------+----------------+                              |            |           
   |                                         set result/ trigger runner  |           
   |-------------------------------------------------------------------->|           
                                                            |            |  +----------+
                                                            | finnal     |  |set answer|
                                                            | callback   |  +----------+
                                                            +---<--------+
                                                           
                                                           
```                                                        
                                                           
</details>                                                 
                                                           
### tornado ioloop                                         
                                                           
                                                                                                       
<details close>                                                                                        
  <summary>code</summary>                                  
                                                           
```python                                                  
                                                           
class PollIOLoop(IOLoop):                                  
    ....                                                   
                                                           
    def start(self):                                       
        if not logging.getLogger().handlers:               
            # The IOLoop catches and logs exceptions, so i 's
            # important that log output be visible.  Howev r, python's
            # default behavior for non-root loggers (prior to python
            # 3.2) is to print an unhelpful "no handlers c uld be
            # found" message rather than the actual log en ry, so we
            # must explicitly configure logging if we've m de it this
            # far without anything.                        
            logging.basicConfig()                          
        if self._stopped:                                  
            self._stopped = False                          
            return                                         
        old_current = getattr(IOLoop._current, "instance", None)
        IOLoop._current.instance = self                    
        self._thread_ident = thread.get_ident()            
        self._running = True                               
                                                           
        # signal.set_wakeup_fd closes a race condition in  vent loops:
        # a signal may arrive at the beginning of select/p ll/etc
        # before it goes into its interruptible sleep, so  he signal
        # will be consumed without waking the select.  The solution is
        # for the (C, synchronous) signal handler to write to a pipe,
        # which will then be seen by select.               
        #                                                  
        # In python's signal handling semantics, this only matters on the
        # main thread (fortunately, set_wakeup_fd only works on the main
        # thread and will raise a ValueError otherwise).
        #
        # If someone has already set a wakeup fd, we don't want to
        # disturb it.  This is an issue for twisted, which does its
        # SIGCHILD processing in response to its own wakeup fd being
        # written to.  As long as the wakeup fd is registered on the IOLoop,
        # the loop will still wake up and everything should work.
        old_wakeup_fd = None
        if hasattr(signal, 'set_wakeup_fd') and os.name == 'posix':
            # requires python 2.6+, unix.  set_wakeup_fd exists but crashes
            # the python process on windows.
            try:
                old_wakeup_fd = signal.set_wakeup_fd(self._waker.write_fileno())
                if old_wakeup_fd != -1:
                    # Already set, restore previous value.  This is a little racy,
                    # but there's no clean get_wakeup_fd and in real use the
                    # IOLoop is just started once at the beginning.
                    signal.set_wakeup_fd(old_wakeup_fd)
                    old_wakeup_fd = None
            except ValueError:  # non-main thread
                pass

        while True:
            poll_timeout = 3600.0

            # Prevent IO event starvation by delaying new callbacks
            # to the next iteration of the event loop.
            with self._callback_lock:
                callbacks = self._callbacks
                self._callbacks = []
            for callback in callbacks:
                self._run_callback(callback)

            if self._timeouts:
                now = self.time()
                while self._timeouts:
                    if self._timeouts[0].callback is None:
                        # the timeout was cancelled
                        heapq.heappop(self._timeouts)
                        self._cancellations -= 1
                    elif self._timeouts[0].deadline <= now:
                        timeout = heapq.heappop(self._timeouts)
                        self._run_callback(timeout.callback)
                    else:
                        seconds = self._timeouts[0].deadline - now
                        poll_timeout = min(seconds, poll_timeout)
                        break
                if (self._cancellations > 512
                        and self._cancellations > (len(self._timeouts) >> 1)):
                    # Clean up the timeout queue when it gets large and it's
                    # more than half cancellations.
                    self._cancellations = 0
                    self._timeouts = [x for x in self._timeouts
                                      if x.callback is not None]
                    heapq.heapify(self._timeouts)

            if self._callbacks:
                # If any callbacks or timeouts called add_callback,
                # we don't want to wait in poll() before we run them.
                poll_timeout = 0.0

            if not self._running:
                break

            if self._blocking_signal_threshold is not None:
                # clear alarm so it doesn't fire while poll is waiting for
                # events.
                signal.setitimer(signal.ITIMER_REAL, 0, 0)

            try:
                event_pairs = self._impl.poll(poll_timeout)
            except Exception as e:
                # Depending on python version and IOLoop implementation,
                # different exception types may be thrown and there are
                # two ways EINTR might be signaled:
                # * e.errno == errno.EINTR
                # * e.args is like (errno.EINTR, 'Interrupted system call')
                if (getattr(e, 'errno', None) == errno.EINTR or
                    (isinstance(getattr(e, 'args', None), tuple) and
                     len(e.args) == 2 and e.args[0] == errno.EINTR)):
                    continue
                else:
                    raise

            if self._blocking_signal_threshold is not None:
                signal.setitimer(signal.ITIMER_REAL,
                                 self._blocking_signal_threshold, 0)

            # Pop one fd at a time from the set of pending fds and run
            # its handler. Since that handler may perform actions on
            # other file descriptors, there may be reentrant calls to
            # this IOLoop that update self._events
            self._events.update(event_pairs)
            while self._events:
                fd, events = self._events.popitem()
                try:
                    self._handlers[fd](fd, events)
                except (OSError, IOError) as e:
                    if e.args[0] == errno.EPIPE:
                        # Happens when the client closes the connection
                        pass
                    else:
                        app_log.error("Exception in I/O handler for fd %s",
                                      fd, exc_info=True)
                except Exception:
                    app_log.error("Exception in I/O handler for fd %s",
                                  fd, exc_info=True)
        # reset the stopped flag so another start/stop pair can be issued
        self._stopped = False
        if self._blocking_signal_threshold is not None:
            signal.setitimer(signal.ITIMER_REAL, 0, 0)
        IOLoop._current.instance = old_current
        if old_wakeup_fd is not None:
            signal.set_wakeup_fd(old_wakeup_fd)
```
</details>

参考文章:
- [我所理解的 tornado - ioloop 部分](https://juejin.im/entry/58c613762f301e006bc6d700)
- [深入理解 tornado 之底层 ioloop 实现](https://segmentfault.com/a/1190000005659237)
