//
//  DeleteSegment.m
//  insert_dylib
//
//  Created by QiuChenly on 2024/1/7.
//  Copyright © 2024 Tyilo. All rights reserved.
//
//  main.m

#import <Foundation/Foundation.h>
#include <mach-o/loader.h>
#include <mach-o/swap.h>
#include <mach-o/fat.h>

//MARK: - 定义一些工具方法
BOOL isFatOfMagic(uint32 magic) {
    return magic == FAT_MAGIC || magic == FAT_CIGAM;
}

BOOL isMagic64(uint32 magic) {
    return magic == MH_MAGIC_64 || magic == MH_CIGAM_64;
}

BOOL shouldSwapBytesOfMagic(uint32 magic) {
    return magic == MH_CIGAM || magic == MH_CIGAM_64 || magic == FAT_CIGAM || magic == FAT_CIGAM_64;
}

BOOL isValidMachoOfMagic(uint32 magic) {
    return magic == FAT_MAGIC || magic == FAT_CIGAM || magic == MH_MAGIC_64 || magic == MH_CIGAM_64;
}

@interface NSFileHandle (Extension)
- (NSData *)readDataFromOffSet:(unsigned long long)offset length:(NSUInteger)length;

- (const void *)readBytesFromOffSet:(unsigned long long)offset length:(NSUInteger)length;

- (void)writeData:(NSData *)data offSet:(unsigned long long)offset;

- (void)writeBytes:(void *)bytes offSet:(unsigned long long)offSet length:(NSUInteger)length;

+ (void)insert:(NSString *)filePath toInsertData:(NSData *)toInsertData offset:(long)offset;

+ (void)delete:(NSString *)filePath offset:(long)offset size:(long)size;
@end

@implementation NSFileHandle (Extension)
- (NSData *)readDataFromOffSet:(unsigned long long)offset length:(NSUInteger)length {
    [self seekToFileOffset:offset];
    return [self readDataOfLength:length];
}

- (const void *)readBytesFromOffSet:(unsigned long long)offSet length:(NSUInteger)length {
    return [[self readDataFromOffSet:offSet length:length] bytes];
}

- (void)writeData:(NSData *)data offSet:(unsigned long long)offset {
    [self seekToFileOffset:offset];
    [self writeData:data];
}

- (void)writeBytes:(void *)bytes offSet:(unsigned long long)offSet length:(NSUInteger)length {
    NSData *d = [[NSData alloc] initWithBytes:bytes length:length];
    [self writeData:d offSet:offSet];
}

+ (void)insert:(NSString *)filePath toInsertData:(NSData *)toInsertData offset:(long)offset {
    NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    [fh seekToFileOffset:offset];
    NSData *remainData = [fh readDataToEndOfFile];
    [fh truncateFileAtOffset:offset];
    [fh writeData:toInsertData];
    [fh writeData:remainData];
    [fh synchronizeFile];
    [fh closeFile];
}

+ (void)delete:(NSString *)filePath offset:(long)offset size:(long)size {
    NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    [fh seekToFileOffset:offset + size];
    NSData *remainData = [fh readDataToEndOfFile];
    [fh truncateFileAtOffset:offset];
    [fh writeData:remainData];
    [fh synchronizeFile];
    [fh closeFile];
}
@end

//Demo 主逻辑
//代码来自https://blog.csdn.net/jerryandliujie/article/details/84845162
bool delete_dylib(
        const char *macho_path,
        const char *segment_name
) {
    NSString *toDeleteDylibLink = [NSString stringWithUTF8String:segment_name];
    NSString *machoFilePath = [NSString stringWithUTF8String:macho_path];
    NSFileHandle *machoFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:machoFilePath];
    /* 读取魔数（前4个字节）
     要注意的是，后面还有一个魔数，是MachO部分的，此处是针对 fat_arch 和 fat_header 相关信息的。
     后面的是用于某个arch下的 MachO 的。
     */
    uint32 magic = *((uint32 *) [machoFileHandle readBytesFromOffSet:0 length:4]);
    //thin 还是 fat 版本
    BOOL isFat = isFatOfMagic(magic);
    //是否是64位
    BOOL is64 = isMagic64(magic);
    //大小端转换判断
    BOOL shouldSwap = shouldSwapBytesOfMagic(magic);

    if (isFat) {
        int fat_header_size = sizeof(struct fat_header);
        struct fat_header *fatHeader = (struct fat_header *) [machoFileHandle readBytesFromOffSet:0 length:fat_header_size];
        if (shouldSwap) {
            swap_fat_header(fatHeader, 0);
        }
        int arch_offset = fat_header_size;
        uint64_t machHeaderOffset = 0;
        //遍历所有 arch
        for (int i = 0; i < fatHeader->nfat_arch; i++) {
            if (is64) {
                int fat_arch_size = sizeof(struct fat_arch_64);
                struct fat_arch_64 *arch = (struct fat_arch_64 *) [machoFileHandle readBytesFromOffSet:arch_offset length:fat_arch_size];
                if (shouldSwap) {
                    //大小端转换
                    swap_fat_arch_64(arch, 1, 0);
                }
                //保存 mach header 的起始位置
                machHeaderOffset = arch->offset;
                //计算下一个 fat_arch 的起始位置
                arch_offset += fat_arch_size;
            } else {
                int fat_arch_size = sizeof(struct fat_arch);
                struct fat_arch *arch = (struct fat_arch *) [machoFileHandle readBytesFromOffSet:arch_offset length:fat_arch_size];
                if (shouldSwap) {
                    swap_fat_arch(arch, 1, 0);
                }
                machHeaderOffset = arch->offset;
                arch_offset += fat_arch_size;
            }

            /*------ 开始读取 mach header ------*/
            //读取魔数(前4个字节)
            uint32 machMagic = *((uint32 *) [machoFileHandle readBytesFromOffSet:machHeaderOffset length:4]);
            BOOL isMach64 = isMagic64(machMagic);
            BOOL shoudMachSwap = shouldSwapBytesOfMagic(machMagic);

            int ncmds = 0;
            long loadCommandsOffset = 0;
            if (isMach64) {
                int machHeaderSize = sizeof(struct mach_header_64);
                struct mach_header_64 *header = (struct mach_header_64 *) [machoFileHandle readBytesFromOffSet:machHeaderOffset length:machHeaderSize];
                if (shoudMachSwap) {
                    swap_mach_header_64(header, 0);
                }
                //获取 load commands 的个数
                ncmds = header->ncmds;
                //load commands的起始位置
                loadCommandsOffset = machHeaderOffset + machHeaderSize;
            } else {
                int machHeaderSize = sizeof(struct mach_header);
                struct mach_header *header = (struct mach_header *) [machoFileHandle readBytesFromOffSet:machHeaderOffset length:machHeaderSize];
                if (shoudMachSwap) {
                    swap_mach_header(header, 0);
                }

                ncmds = header->ncmds;
                loadCommandsOffset = machHeaderOffset + machHeaderSize;
            }
            /*------ 开始读取 load command ------*/
            for (int i = 0; i < ncmds; i++) {
                struct load_command *cmd = (struct load_command *) [machoFileHandle readBytesFromOffSet:loadCommandsOffset length:sizeof(struct load_command)];
                if (shoudMachSwap) {
                    swap_load_command(cmd, 0);
                }
                //如果是 LC_LOAD_DYLIB类型， 则获取 dylib_command
                if (cmd->cmd == LC_LOAD_DYLIB) {
                    struct dylib_command *dylibCmd = (struct dylib_command *) [machoFileHandle readBytesFromOffSet:loadCommandsOffset length:cmd->cmdsize];
                    if (shoudMachSwap) {
                        swap_dylib_command(dylibCmd, 0);
                    }
                    //读取 dylib_command 的 name 信息
                    int pathstringLen = dylibCmd->cmdsize - dylibCmd->dylib.name.offset;
                    char *cPath = (char *) [machoFileHandle readBytesFromOffSet:loadCommandsOffset + dylibCmd->dylib.name.offset length:pathstringLen];
                    NSString *path = [[NSString alloc] initWithUTF8String:cPath];
                    NSLog(@"loading... %@", path);
                    if ([path isEqualToString:toDeleteDylibLink]) {
                        int totalCmdSize = 0;
                        int machHeaderSize = 0;
                        /* 执行删除逻辑 */
                        //更新 header 信息
                        if (isMach64) {
                            machHeaderSize = sizeof(struct mach_header_64);
                            struct mach_header_64 *header = (struct mach_header_64 *) [machoFileHandle readBytesFromOffSet:machHeaderOffset length:machHeaderSize];
                            if (shoudMachSwap) {
                                swap_mach_header_64(header, 0);
                            }

                            totalCmdSize = header->sizeofcmds;
                            header->ncmds -= 1;
                            header->sizeofcmds -= dylibCmd->cmdsize;
                            [machoFileHandle writeBytes:header offSet:machHeaderOffset length:machHeaderSize];
                        } else {
                            machHeaderSize = sizeof(struct mach_header);
                            struct mach_header *header = (struct mach_header *) [machoFileHandle readBytesFromOffSet:machHeaderOffset length:machHeaderSize];
                            if (shoudMachSwap) {
                                swap_mach_header(header, 0);
                            }
                            totalCmdSize = header->sizeofcmds;
                            header->ncmds -= 1;
                            header->sizeofcmds -= dylibCmd->cmdsize;
                            [machoFileHandle writeBytes:header offSet:machHeaderOffset length:machHeaderSize];
                        }
                        //构建 0 字节
                        int n = dylibCmd->cmdsize;
                        uint8 *arr;
                        arr = (uint8 *) malloc(sizeof(uint8) * n);
                        for (int i = 0; i < n; i++)
                            arr[i] = 0;
                        //尾部添加
                        [NSFileHandle insert:machoFilePath toInsertData:[NSData dataWithBytes:arr length:n] offset:machHeaderOffset + machHeaderSize + totalCmdSize];
                        //删除 dylibCmd 占用的字节
                        [NSFileHandle delete:machoFilePath offset:loadCommandsOffset size:dylibCmd->cmdsize];
                        //如果找到后 就return 退出循环
                        return true;
                    }
                }
                //计算下个 load_command 的起始位置
                loadCommandsOffset += cmd->cmdsize;
            }
        }
    } else {
        //如果是 thin 版本，就直接从上面fat版处理步骤中的 "开始读取 mach header" 开始,这里就不再重复实现了。
        assert(false);
    }

    return 0;
}
