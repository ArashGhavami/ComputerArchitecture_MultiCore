# Project 3 – Dual-Core Processor Design

# Introduction

With the increasing demand for computational performance, multi-core processors have become a standard solution. This project focuses on designing and implementing a dual-core processor system. Each core operates independently but shares access to a common memory, requiring careful handling of synchronization and memory consistency.
The main objective is to extend a previously implemented single-core processor into a two-core architecture and analyze the effects of parallel execution on system performance.


# Objectives

1. Understand the architecture of multi-core processors and their advantages.
2. Design and implement a dual-core processor using concepts from single-core design.
3. Explore methods of memory sharing and synchronization between cores.
4. Evaluate system performance compared to a single-core design.

# Project Description
Two independent cores: CPU0 and CPU1
A single shared memory module accessible by both cores.
Requires a control mechanism to handle simultaneous read/write requests.
Priority rules must be established (e.g., CPU0 has priority in case of conflict).

New Instructions Added to this Architecture:

```bash
cpuid rd → Stores the core ID into register rd (0 for CPU0, 1 for CPU1).
sync → Synchronization instruction ensuring both CPUs reach the same execution point before continuing (blocking).
```

Optional Feature (Bonus):
Atomic exchange instruction
```bash
exchng rt, [rs + imm]  
```
Exchanges rt with memory at address [rs + imm].
Can be used to implement spinlocks and synchronization primitives.

# Implementation Steps

Create a base dual-core structure.     
Copy the single-core CPU design into two cores (CPU0 and CPU1).      
Implement independent PCs, ALUs, and registers.     
Connect both cores to a shared memory module.     
Design a write buffer.    
Add a FIFO buffer for memory writes.     
Prevent simultaneous writes from causing conflicts.    
Implement cpuid instruction.    
Each core must return its ID when executing cpuid.    
Implement sync instruction.    
Cores must block until both reach sync, then continue execution together.    
(Bonus) Add spinlock synchronization using exchng.    

# Evaluation & Testing

Comparison Test
Implement matrix multiplication of two 8×8 matrices.
Run once on single-core CPU and once on dual-core CPU.
Measure execution cycles in both cases.
Parallel Workload Division
In dual-core version, divide matrix rows between cores (e.g., CPU0 computes rows 0–3, CPU1 computes rows 4–7).
Use sync to ensure proper coordination.
Performance Analysis
Record and compare the cycle count of single-core vs dual-core.
Show the impact of parallelism on performance.
(Bonus) Demonstrate incorrect memory access using spinlock code to show the importance of synchronization.