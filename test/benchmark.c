// http://developers.redhat.com/blog/2016/03/11/practical-micro-benchmarking-with-ltrace-and-sched/

/* One drawback of the RDTSC instruction is that the CPU is allowed to reorder
   it relative to other instructions, which causes noise in our results. Fortunately,
   Intel has provided an RDTSCP instruction that’s more deterministic. We’ll pair
   that with a CPUID instruction which acts as a memory barrier, resulting in this: */

#define _GNU_SOURCE
#include <stdint.h>
#include <malloc.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>
#include <sched.h>
#define MY_CPU 1
static __inline__ int64_t rdtsc_s(void)
{
  unsigned a, d;
  asm volatile("cpuid" ::: "%rax", "%rbx", "%rcx", "%rdx");
  asm volatile("rdtsc" : "=a" (a), "=d" (d));
  return ((unsigned long)a) | (((unsigned long)d) << 32);
}

static __inline__ int64_t rdtsc_e(void)
{
  unsigned a, d;
  asm volatile("rdtscp" : "=a" (a), "=d" (d));
  asm volatile("cpuid" ::: "%rax", "%rbx", "%rcx", "%rdx");
  return ((unsigned long)a) | (((unsigned long)d) << 32);
}

long write_n_bytes(int bytes) {
  // Schedule
  cpu_set_t my_cpu;
  int my_cpu_num = MY_CPU;
  CPU_ZERO(&my_cpu);
  CPU_SET(my_cpu_num, &my_cpu);
  if (sched_setaffinity(0, sizeof(my_cpu), &my_cpu) == -1) {
    perror("setaffinity failed");
  }

  // Setup
  char *fname = "/home/zeroalpha/adafs/wfile";
  int fd = open(fname, 0);
  char *str = malloc(bytes*sizeof(char));
  memset(str, 51914, bytes);

  // Test
  struct timespec before, after;
  long per;
  clock_gettime(CLOCK_REALTIME, &before);
  write(fd, str, bytes);
  clock_gettime(CLOCK_REALTIME, &after);

  // Cleanup
  close(fd);
  unlink(fname);
  free(str);

  // Return
  per = after.tv_nsec - before.tv_nsec;
  return per;
}

long read_n_bytes(int bytes) {
  // Schedule
  cpu_set_t my_cpu;
  int my_cpu_num = MY_CPU;
  CPU_ZERO(&my_cpu);
  CPU_SET(my_cpu_num, &my_cpu);
  if (sched_setaffinity(0, sizeof(my_cpu), &my_cpu) == -1) {
    perror("setaffinity failed");
  }

  // Setup
  char *fname = "/home/zeroalpha/adafs/rfile";
  char *str = malloc(bytes*sizeof(char));
  memset(str, 51914, bytes);
  int fd = open(fname, 0);
  write(fd, str, bytes);
  close(fd);
  fd = open(fname, 0);

  // Test
  struct timespec before, after;
  long per;
  clock_gettime(CLOCK_REALTIME, &before);
  read(fd, str, bytes);
  clock_gettime(CLOCK_REALTIME, &after);

  // Cleanup
  close(fd);
  unlink(fname);
  free(str);

  // Return
  per = after.tv_nsec - before.tv_nsec;
  return per;
}

long create_file(void) {
  // Schedule
  cpu_set_t my_cpu;
  int my_cpu_num = MY_CPU;
  CPU_ZERO(&my_cpu);
  CPU_SET(my_cpu_num, &my_cpu);
  if (sched_setaffinity(0, sizeof(my_cpu), &my_cpu) == -1) {
    perror("setaffinity failed");
  }

  // Setup
  char *fname = "/home/zeroalpha/adafs/newfile";

  // Test
  struct timespec before, after;
  long per;
  clock_gettime(CLOCK_REALTIME, &before);
  int fd = creat(fname, 0);
  clock_gettime(CLOCK_REALTIME, &after);

  // Cleanup
  close(fd);
  unlink(fname);

  // Return
  per = after.tv_nsec - before.tv_nsec;
  return per;
}

long remove_1kb_file(void) {
  // Schedule
  cpu_set_t my_cpu;
  int my_cpu_num = MY_CPU;
  CPU_ZERO(&my_cpu);
  CPU_SET(my_cpu_num, &my_cpu);
  if (sched_setaffinity(0, sizeof(my_cpu), &my_cpu) == -1) {
    perror("setaffinity failed");
  }

  // Setup
  char *fname = "/home/zeroalpha/adafs/rmfile";
  int fd = open(fname, 0);
  int kb = 1000;
  char *str = calloc(kb, 1);
  memset(str, 51914, kb);
  write(fd, str, kb);
  close(fd);
  free(str);

  // Test
  struct timespec before, after;
  long per;
  clock_gettime(CLOCK_REALTIME, &before);
  unlink(fname);
  clock_gettime(CLOCK_REALTIME, &after);

  // Return
  per = after.tv_nsec - before.tv_nsec;
  return per;
}

int main() {
  printf("create,%ld\n", create_file());
  printf("remove,%ld\n", remove_1kb_file());
  printf("1000x write 1B,%ld\n", write_n_bytes(1));
  printf("1000x write 1KB,%ld\n", write_n_bytes(1024));
  printf("1000x write 10KB,%ld\n", write_n_bytes(10*1024));
  printf("1000x write 100KB,%ld\n", write_n_bytes(100*1024));
  printf("1000x read 1B,%ld\n", read_n_bytes(1));
  printf("1000x read 1KB,%ld\n", read_n_bytes(1024));
  printf("1000x read 10KB,%ld\n", read_n_bytes(10*1024));
  printf("1000x read 100KB,%ld\n", read_n_bytes(100*1024));
  return 0;
}

//  let the OS use CPU #0
// boot options:
// linux . . . isolcpus=1,2,3,4,5,6,7

// check:
// taskset -p $$

// Interrupt affinity:
// cd /proc/irq
// for i in */smp_affinity; do echo 1 > $i; done

