// http://developers.redhat.com/blog/2016/03/11/practical-micro-benchmarking-with-ltrace-and-sched/

/* One drawback of the RDTSC instruction is that the CPU is allowed to reorder
   it relative to other instructions, which causes noise in our results. Fortunately,
   Intel has provided an RDTSCP instruction that’s more deterministic. We’ll pair
   that with a CPUID instruction which acts as a memory barrier, resulting in this: */

#include <stdint.h>
#include <malloc.h>
#include <stdio.h>
#include <string.h>

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

int64_t write_n_bytes(int bytes) {
  int64_t clocks_before, clocks_after, clocks_per;
  char *str = malloc(bytes*sizeof(char));
  memset(str, 51914, bytes);
  FILE *fp;
  fp = fopen("/home/zeroalpha/adafs/write_bytes", "w");
  clocks_before = rdtsc_s();
  fwrite(str, sizeof(char), bytes, fp);
  clocks_after = rdtsc_e();
  fclose(fp);
  free(str);
  clocks_per = clocks_after-clocks_before;
  return clocks_per;
}
int main() {
  printf("%ld\n", write_n_bytes(10*1024));
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

