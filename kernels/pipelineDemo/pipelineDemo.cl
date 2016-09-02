#define MAX_REC_N 128
#define PIPE_LEN 16

pipe int p0 __attribute__((xcl_reqd_pipe_depth(PIPE_LEN)));



kernel __attribute__((reqd_work_group_size(1, 1, 1)))
void kernel1(__global int *g_output)
{
    __local int l_output[MAX_REC_N];

    for (int i = 0; i < MAX_REC_N; ) {
        printf("read_pipe(p0, %d)\n", i);
        int ret = read_pipe(p0, &l_output[i]);
        if (ret == 0) {
            printf("read_pipe(p0, %d) Succeeded\n", i);
            i++;
        } else{
            printf("read_pipe(p0, %d) Failed\n", i);
        }
    }

    printf("async_work_group_copy in kernel1");
    async_work_group_copy(g_output, l_output, MAX_REC_N, 0);
    printf("async_work_group_copy finished in kernel1");
    return;
}

/*
it only runs the kernel0, 也不可能分成好几个文件。。。 Because pipe is defined at file scope.
So I must make that pipe sample works.
*/

kernel __attribute__((reqd_work_group_size(1, 1, 1)))
void kernel0(__global int *g_input)
{
    __local int l_input[MAX_REC_N];

    // async + pipeline => good performance.
    // printf("async_work_group_copy in kernel0");
    async_work_group_copy(l_input, g_input, MAX_REC_N, 0);
    // printf("async_work_group_copy finished in kernel0");

    for (int i = 0; i < MAX_REC_N;) {
        printf("write_pipe(p0, %d)\n", i);
        int ret = write_pipe(p0, &l_input[i]);
        if (ret == 0) {
            printf("write_pipe(p0, %d) Succeeded.\n", i);
            i++;
        }else{
            printf("write_pipe(p0, %d) Failed.\n", i);
        }
    }

    return;
}


/*
大概知道怎么回事了， 只有第一个kernel有input， 最后一个kernel有output， 然后enqueue全部，
等待所有kernel执行完毕， 要根据此修改helper.cpp, 变为一次运行多个kernel的感觉。
具体kernel内部的pipe关系，是在kernel.cl这个文件里面处理的。
*/


/*
#include <clc.h>   // needed for OpenCL kernels
// 这个解决方式很不错，也算是全体pipeline了吧， 那个邮件不用发了。
pipe int p0 __attribute__((xcl_reqd_pipe_depth(512)));
pipe int p1 __attribute__((xcl_reqd_pipe_depth(512)));
// Stage 1
kernel __attribute__ ((reqd_work_group_size(256, 1, 1)))
void input_stage(__global int *input) {
write_pipe(p0, &input[get_local_id(0)]);
}
// Stage 2
kernel __attribute__ ((reqd_work_group_size(256, 1, 1)))
void adder_stage(int inc) {
int input_data, output_data;
read_pipe(p0, &input_data);
output_data = input_data + inc;
write_pipe(p1, &output_data);
}
// Stage 3
kernel __attribute__ ((reqd_work_group_size(256, 1, 1)))
void output_stage(__global int *output) {
read_pipe(p1, &output[get_local_id(0)]);
}
*/
