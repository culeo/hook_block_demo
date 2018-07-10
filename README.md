
### 题目

![](https://wx3.sinaimg.cn/mw690/51530583ly1fsatleo2zmj213u10caiu.jpg)

来自：[Link](https://weibo.com/1364395395/Gll7m2EVJ?filter=hot&root_comment_id=0&type=comment#_rnd1531211687237)


### 思路（详见代码）

##### 第一题

直接修改 _FuncPtr 指向即可。

```c
struct __block_imp {
    Class _isa;
    int _flags;
    int _reserver;
    void *_FuncPtr;
};
```

##### 第二题

利用 ffi hook block 即可。

##### 第三题

用 [fishhook](https://github.com/facebook/fishhook) hook objc_retainBlock 方法，新方法调用第二题方法即可。

### 阅读


- [对Objective-C中Block的追探](http://www.cnblogs.com/biosli/archive/2013/05/29/iOS_Objective-C_Block.html)
- [Hook Objective-C Block with Libffi](http://yulingtianxia.com/blog/2018/02/28/Hook-Objective-C-Block-with-Libffi/)
- [MABlockClosure](https://github.com/mikeash/MABlockClosure)
- [Skifary/main.m](https://gist.github.com/Skifary/497ad1ee4bf7f57d8093463cfabd1c1f)