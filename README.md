insert_dylib Plus
============

## 原作者信息
原作者: Tyilo <br>
源仓库地址: https://github.com/Tyilo/insert_dylib

## 增加的功能
1. 支持通过--delete_dylib实现删除指定的dylib,同时自动修正Mach-O文件头偏移。
2. 忘了
   
## 代码来源资料
1. https://blog.csdn.net/jerryandliujie/article/details/84845162 By nsrx

## 介绍
这是一个可以将dylib插入到目标Mach-O中的工具。

对于多架构FAT(AARCH64/Intel)依托钩式的苹果架构，做到了如下功能:

- 暴力增加一个 `LC_LOAD_DYLIB` 命令到Command列表的底部。
- 增加Mach-O文件头中的 `ncmds` 计数并自动调整 `sizeofcmds`。
- ([根据需要自动删除代码签名](#removing-code-signature))

用法
-----

```
用法: insert_dylib 注入库路径 原始二进制路径 [修改后的二进制路径]
可选功能: --inplace --weak --overwrite --strip-codesig --no-strip-codesig --not-all-yes --delete_dylib
```

`insert_dylib` 插入一个库加载命令 `dylib_path` 在 `binary_path`中.

如果指定 `--inplace` 选项, `insert_dylib` 将会自动复制原始文件并写入到 `new_binary_path`.  

如果指定 `--inplace` 且 `new_binary_path` 被指定, 输出的二进制将会自动复制原始文件并重命名为 `_patched` 到原始二进制相同的目录中.

如果 `--weak` 选项被指定, `insert_dylib` 将会插入一个 `LC_LOAD_WEAK_DYLIB` 加载指令替换掉 `LC_LOAD_DYLIB`.

如果`--not-all-yes`被指定,那么所有的操作会等待询问你才会进行下一步。

如果`--delete_dylib`被指定，则会自动在目标二进制中查询`dylib_path`符合的LC_LOAD_DYLIB指令并删除，保存行为与上面保持一致。


### 使用例子

//这里是我新增的例程

`--delete_dylib` 选项

原始文件被注入了一个libHello文件
```bash
otool -L /Applications/iShot.app/Contents/Frameworks/PTHotKey.framework/Versions/A/PTHotKey
/Applications/iShot.app/Contents/Frameworks/PTHotKey.framework/Versions/A/PTHotKey:
	@rpath/PTHotKey.framework/Versions/A/PTHotKey (compatibility version 1.0.0, current version 1.6.0)
	/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 1770.106.0)
	/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0, current version 2022.0.0)
	/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon (compatibility version 2.0.0, current version 164.0.0)
	/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1292.0.0)
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 1770.106.0)
	/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices (compatibility version 1.0.0, current version 1122.4.0)
	/Users/qiuchenly/Library/Developer/Xcode/DerivedData/Hello-fixfsrfqwilrgwgtuhcgbxmlerow/Build/Products/Debug/libHello.dylib (compatibility version 0.0.0, current version 0.0.0)
```
执行:
```bash
sudo /Users/qiuchenly/Library/Developer/Xcode/DerivedData/insert_dylib-enqilexhbjsajadynnbudkehezmz/Build/Products/Release/insert_dylib /Users/qiuchenly/Library/Developer/Xcode/DerivedData/Hello-fixfsrfqwilrgwgtuhcgbxmlerow/Build/Products/Debug/libHello.dylib /Applications/iShot.app/Contents/Frameworks/PTHotKey.framework/Versions/A/PTHotKey /Applications/iShot.app/Contents/Frameworks/PTHotKey.framework/Versions/A/PTHotKey_rm --delete_dylib


====================
2023.2.26 秋城落叶修改版
感谢insert_dylib的开源人员！仓库地址：https://github.com/Tyilo/insert_dylib
====================

2024-01-07 03:41:51.540 insert_dylib[39885:983858] loading... /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation
2024-01-07 03:41:51.540 insert_dylib[39885:983858] loading... /System/Library/Frameworks/AppKit.framework/Versions/C/AppKit
2024-01-07 03:41:51.540 insert_dylib[39885:983858] loading... /System/Library/Frameworks/Carbon.framework/Versions/A/Carbon
2024-01-07 03:41:51.540 insert_dylib[39885:983858] loading... /usr/lib/libobjc.A.dylib
2024-01-07 03:41:51.540 insert_dylib[39885:983858] loading... /usr/lib/libSystem.B.dylib
2024-01-07 03:41:51.540 insert_dylib[39885:983858] loading... /System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation
2024-01-07 03:41:51.540 insert_dylib[39885:983858] loading... /System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices
2024-01-07 03:41:51.540 insert_dylib[39885:983858] loading... /Users/qiuchenly/Library/Developer/Xcode/DerivedData/Hello-fixfsrfqwilrgwgtuhcgbxmlerow/Build/Products/Debug/libHello.dylib
删除/Users/qiuchenly/Library/Developer/Xcode/DerivedData/Hello-fixfsrfqwilrgwgtuhcgbxmlerow/Build/Products/Debug/libHello.dylib /Applications/iShot.app/Contents/Frameworks/PTHotKey.framework/Versions/A/PTHotKey_rm的LC_Command成功。%                                                                                            ❯ otool -L /Applications/iShot.app/Contents/Frameworks/PTHotKey.framework/Versions/A/PTHotKey_rm
/Applications/iShot.app/Contents/Frameworks/PTHotKey.framework/Versions/A/PTHotKey_rm:
	@rpath/PTHotKey.framework/Versions/A/PTHotKey (compatibility version 1.0.0, current version 1.6.0)
	/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 1770.106.0)
	/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0, current version 2022.0.0)
	/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon (compatibility version 2.0.0, current version 164.0.0)
	/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1292.0.0)
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 1770.106.0)
	/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices (compatibility version 1.0.0, current version 1122.4.0)
```
`libHello.dylib`已经被移除。


//下面是原作者的

```
$ cat > test.c
int main(void) {
	printf("Testing\n");
	return 0;
}
^D
$ clang test.c -o test &> /dev/null
$ insert_dylib /usr/lib/libfoo.dylib test
The provided dylib path doesn't exist. Continue anyway? [y/n] y
Added LC_LOAD_DYLIB to test_patched
$ ./test
Testing
$ ./test_patched
dyld: Library not loaded: /usr/lib/libfoo.dylib
  Referenced from: /Users/Tyilo/./test_patched
  Reason: image not found
Trace/BPT trap: 5
```

#### `otool` `diff` between original and patched binary
```
$ diff -u <(otool -hl test) <(otool -hl test_patched)
--- /dev/fd/63	2014-07-30 04:08:40.000000000 +0200
+++ /dev/fd/62	2014-07-30 04:08:40.000000000 +0200
@@ -1,7 +1,7 @@
-test:
+test_patched:
 Mach header
       magic cputype cpusubtype  caps    filetype ncmds sizeofcmds      flags
- 0xfeedfacf 16777223          3  0x80          2    16       1296 0x00200085
+ 0xfeedfacf 16777223          3  0x80          2    17       1344 0x00200085
 Load command 0
       cmd LC_SEGMENT_64
   cmdsize 72
@@ -231,3 +231,10 @@
   cmdsize 16
   dataoff 8296
  datasize 64
+Load command 16
+          cmd LC_LOAD_DYLIB
+      cmdsize 48
+         name /usr/lib/libfoo.dylib (offset 24)
+   time stamp 0 Thu Jan  1 01:00:00 1970
+      current version 0.0.0
+compatibility version 0.0.0
```

#### `--weak` option

```
$ insert_dylib --weak /usr/lib/libfoo.dylib test test_patched2
The provided dylib path doesn't exist. Continue anyway? [y/n] y
Added LC_LOAD_WEAK_DYLIB to test_patched2
$ ./test_patched2
Testing
```

Removing code signature
----

To remove the code signature it is enough to delete the `LC_CODE_SIGNATURE` load command and fixup the mach header's `ncmds` and `sizeofcmds`, assuming it is the last load command.

However if you just do this `codesign_allocate` (used by `codesign` and `ldid`) will fail with the error:

```
.../codesign_allocate: file not in an order that can be processed (link edit information does not fill the __LINKEDIT segment):
```

To fix this `insert_dylib` assumes that the code signature that `LC_CODE_SIGNATURE` is in the end of the `__LINKEDIT` segment and the that the segment is in the end of the architectures slice.

It then truncate that slice to remove the code signature part of the `__LINKEDIT` segment. It also updates the `LC_SEGMENT` (or `LC_SEGMENT64`) load command for the `__LINKEDIT` segment from the new file size. If the binary is fat we also update the size and we might also move the slice and so the offset should also be updated.

After removing the code signature from the `__LINKEDIT` segment, the last thing in that segment is typically the string table. As the code signature seems to be aligned by `0x10`, and so after removing the code signature, nothing points to the padding at the end of the segment, which `codesign_allocate` doesn't like either. To fix this we just increase the size of the string table in the `LC_SYMTAB` command so it also includes the padding.

Todo
----

- Improved checking for free space to insert the new load command
- Allow removal of `LC_CODE_SIGNATURE` if it isn't the last load command
- Remove `__RESTRICT,__restrict` if not enough space (suggesion by dirkg)# InsertDylib
