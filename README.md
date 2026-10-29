# Day 27 — Round-Robin Arbiter Design and Verification

<p align="center">
  <b>Digital VLSI · Verilog RTL · Arbitration · Control Logic · Cadence Genus</b>
</p>

<p align="center">
  <code>Specification → RTL → Testbench → Simulation Review → Synthesis → Area → Power → Timing → PPA Review</code>
</p>

<p align="center">
  <img alt="Project" src="https://img.shields.io/badge/Project-Round--Robin%20Arbiter-blue">
  <img alt="HDL" src="https://img.shields.io/badge/HDL-Verilog-8A2BE2">
  <img alt="Synthesis" src="https://img.shields.io/badge/Synthesis-Cadence%20Genus-orange">
  <img alt="Verification" src="https://img.shields.io/badge/Verification-500%20Pass%20%7C%200%20Fail-success">
</p>

---

## 1. Project Information

| Parameter | Details |
|---|---|
| **Project** | Day 27 — Round-Robin Arbiter Design and Verification |
| **Author** | Omkar Kalmesh Hadapad |
| **Domain** | Digital VLSI / RTL Design / Functional Verification |
| **Design type** | Round-robin resource arbiter with owner-control and wait-counter logic |
| **HDL** | Verilog RTL |
| **Top module** | `round_robin_arbiter` |
| **Key hierarchy blocks** | `request_mask`, `wait_counter`, owner-control logic |
| **Simulation testbench** | `day27_tb.v` |
| **Simulation tool shown in transcript** | Cadence NCSim (`ncsim`) |
| **Synthesis tool** | Cadence Genus 21.14-s082_1 |
| **Technology library** | `tsmc18` |
| **Reported test log** | 500 `STATUS: PASS` entries; 0 reported failures |
| **Named test labels** | 499; one PASS record in the visible log has no scenario/test label |
| **Synthesis cell count** | 148 standard-cell instances |
| **Reported cell area** | 3130.142 library area units |
| **Estimated total power** | 231.226 µW |
| **Timing evidence** | One reported setup path marked MET with +2.278 ns slack |
| **Physical-design status** | Post-route PPA closure not established |

> **Measurement and evidence note:** The area unit is not explicitly confirmed in the supplied report, so it is described as *reported library area units*, not assumed to be µm². The power value is an estimate from the supplied power report. The test log ends with an overall PASS and an NCSim `$finish` line, but it also contains a note saying the RTL simulation must still be run with the installed simulator. Treat the log as a reported verification summary until a fresh simulator run is confirmed.

---

## 2. Project Overview

A round-robin arbiter selects one requester from multiple competing requesters while advancing the priority position so eligible requesters can receive service in turn. Unlike a fixed-priority arbiter, a correctly implemented round-robin policy is intended to avoid permanently favoring one requester when competing requests remain eligible.

The supplied Day 27 materials identify the `round_robin_arbiter` design and report verification scenarios for aging/wait logic, round-robin selection, owner control, wait-counter behavior, and top-level integration. The hierarchy report identifies `request_mask` and `wait_counter` as named submodules.

The available reports support a synthesis-stage area and power review, plus inspection of one timing path. They do not establish routed implementation or extracted-parasitic PPA closure.

### Main design topics

- Round-robin request selection.
- Request masking and eligibility.
- Owner/grant consistency.
- Wait or aging logic.
- Wait-counter reset, increment, hold, clear, and saturation behavior.
- Resource-unavailable and fault-blocking behavior.
- Functional verification and top-level integration.
- Cadence Genus technology mapping and PPA report interpretation.

---

## 3. Objectives

1. Understand the purpose of round-robin arbitration.
2. Review request eligibility and priority rotation.
3. Verify that grants are consistent with the owner state.
4. Exercise wait-counter reset, increment, hold, clear, and saturation behavior.
5. Check aging/wait logic across the input combinations represented in the test log.
6. Verify owner acquisition, completion, and fault-related control.
7. Verify behavior when no resource or no request is available.
8. Review the simulation log and distinguish reported results from a confirmed fresh run.
9. Analyze mapped standard-cell count and area.
10. Interpret internal, switching, and leakage power.
11. Review setup timing evidence and identify remaining constraint concerns.
12. Define what is still needed before claiming full timing or physical-design closure.

---

## 4. Conceptual Architecture

```text
                    round_robin_arbiter
                             |
             +---------------+----------------+
             |               |                |
             v               v                v
       Request inputs   Owner control     Wait / aging logic
             |               |                |
             v               v                v
       Request mask     Owner state       Wait counter
             |               |                |
             +---------------+----------------+
                             |
                             v
                    Eligible request set
                             |
                             v
                  Round-robin selection logic
                             |
                             v
                       Grant / owner
```

This is a conceptual view based on the available hierarchy and test labels. The exact port list, state encoding, arbitration equations, and internal connectivity must be confirmed from the RTL source.

### Reported hierarchy

```text
round_robin_arbiter
├── u_mask         (request_mask)
└── u_wait_counter (wait_counter)
```

The synthesis hierarchy report identifies these two named submodules. Other control and selection logic may be implemented in the top module or mapped logic; the available hierarchy summary does not provide a complete RTL-level breakdown of every function.

| Block | Reported purpose inferred from name and test labels |
|---|---|
| `u_mask` / `request_mask` | Request eligibility or masking |
| `u_wait_counter` / `wait_counter` | Wait/aging counter behavior |
| Owner-control logic | Owner acquisition, completion, fault handling, and IDLE blocking |
| Round-robin selector | Eligible request selection and priority progression |
| Top-level integration | Grant, resource availability, fault blocking, and owner/grant consistency |

---

## 5. Round-Robin Operation

A typical round-robin arbiter follows this conceptual sequence:

1. Sample the current request vector.
2. Remove requests that are ineligible, masked, or blocked by resource/fault conditions.
3. Begin selection from the current priority position.
4. Select one eligible requester.
5. Assert a grant consistent with the selected owner.
6. Advance the priority position according to the implemented completion/ownership policy.
7. Repeat when another arbitration decision is permitted.

The exact arbitration timing and the point at which the priority pointer advances depend on the RTL specification. Do not assume a specific grant encoding, number of requesters, or state-transition policy without checking the source code.

### Conceptual priority rotation

```text
Arbitration round 1:  R0 → R1 → R2 → R3 → ...
Arbitration round 2:  start from the next eligible position
Arbitration round 3:  continue rotating among eligible requesters
```

This illustration explains the policy only; it is not a claim that every requester is granted in every cycle.

---

## 6. Functional Verification Review

### Reported test-log summary

| Metric | Observed in supplied log |
|---|---:|
| `STATUS: PASS` entries | **500** |
| Explicit failure entries | **0** |
| Named test labels | **499** |
| Aging-logic scenario records | 415 |
| Round-robin selector records | 64 |
| Owner-control records | 8 |
| Wait-counter records | 7 |
| Top-level integration records | 5 |
| Overall result line | `PASS \| errors=0` |
| Testbench `$finish` time | `70006 NS` in the transcript |

The log contains 500 PASS status records. One PASS record at the beginning of the visible file has no accompanying scenario/test label, so the number of named test labels is 499.

### Reported scenario coverage

| Scenario | Reported checks or behavior |
|---|---|
| `AGING_LOGIC` | Group completion states that 65,536 urgency/wait combinations were checked |
| `RR_SELECTOR` | Group completion states that 64 eligible/pointer combinations were checked |
| `WAIT_COUNTER` | Reset, increment, independent lanes, saturation, hold, and clear checked |
| `OWNER_CTRL` | Acquire, completion, safe/unsafe fault, and IDLE blocking checked |
| `TOP_INTEGRATION` | Priority, owner/grant consistency, round-robin progression, resource blocking, and fault blocking checked |

The scenario counts above are visible log-record counts, not necessarily the total number of internal combinations evaluated by the testbench. The group-completion lines separately report the larger combination counts for aging logic and the selector.

### Example top-level cases in the transcript

The tail of the supplied log includes passing cases labelled:

- `top RR grant R2`
- `top no resource`
- `top fault block`
- `top no requests`

The final transcript lines report:

```text
OVERALL RESULT: PASS | errors=0
Simulation complete via $finish(1) at time 70006 NS + 0
./day27_tb.v:583         $finish;
ncsim>
```

### Important verification qualification

The same log also includes:

```text
NOTE: RTL simulation still must be run with your installed simulator.
NOTE: This is not a formal proof or safety certification.
```

Because the log contains both a PASS summary and this note, the safest documentation is: **the supplied log reports 500 PASS statuses and zero failures; confirm with a fresh run of the actual RTL testbench before claiming the simulation has been independently reproduced.**

The available log does not establish formal proof, safety certification, exhaustive state-space coverage, or CDC/metastability sign-off.

### Recommended additional verification

- Confirm reset assertion and release behavior.
- Check no grant when there are no eligible requests.
- Check no grant when the resource is unavailable.
- Check grant suppression under fault conditions.
- Check owner/grant consistency through acquisition and completion.
- Check round-robin progression under sustained competing requests.
- Check fairness under different request arrival patterns.
- Check wait-counter saturation and clear boundaries.
- Check simultaneous request changes and completion events.
- Run the testbench from the current RTL with the installed simulator and preserve the command transcript, exit status, and waveform if available.

---

## 7. Genus Synthesis Results

The supplied Genus standard-cell report gives the following synthesis snapshot.

| Metric | Reported value |
|---|---|
| Top module | `round_robin_arbiter` |
| Standard-cell instances | **148** |
| Total cell area | **3130.142 library area units** |
| Technology library | `tsmc18` |
| Operating condition | `slow (balanced_tree)` |
| Wireload mode | `enclosed` |
| Area mode | `timing library` |
| Synthesis tool | Cadence Genus 21.14-s082_1 |

These are synthesis-stage metrics. They do not by themselves represent placed-and-routed area or prove physical-design closure.

---

## 8. Standard-Cell Mapping and Area Distribution

### Cell-category summary

| Category | Instances | Reported area | Reported share |
|---|---:|---:|---:|
| Sequential | 19 | 1420.373 | 45.4% |
| Inverter | 21 | 139.709 | 4.5% |
| Logic | 108 | 1570.061 | 50.2% |
| Physical cells | 0 | 0.000 | 0.0% |
| **Total** | **148** | **3130.142** | **100.0% approximately** |

The percentages sum to approximately 100% because of rounding.

### Selected mapped cells

| Cell type | Instances | Reported area |
|---|---:|---:|
| `DFFRHQX1` | 13 | 908.107 |
| `SDFFRHQX1` | 2 | 166.320 |
| `SDFFRHQXL` | 3 | 249.480 |
| `SDFFSRX2` | 1 | 96.466 |
| `NAND2BX1` | 14 | 186.278 |
| `AOI21X1` | 12 | 159.667 |
| `NOR2X1` | 13 | 129.730 |
| `OAI21XL` | 8 | 106.445 |
| `XNOR2X1` | 4 | 106.445 |

### Interpretation

- Sequential cells contribute approximately 45.4% of the reported area.
- Combinational logic contributes approximately 50.2%, making it slightly larger than the sequential category.
- `DFFRHQX1` is the largest individual cell type by combined area among the listed sequential cells.
- `NAND2BX1` and `AOI21X1` are notable contributors among the listed combinational cells.
- A cell-type area ranking is not the same as a timing-criticality ranking; timing reports and path context are needed to identify the critical logic.

The library's exact pin functions and sequential-cell control semantics should be confirmed against the `tsmc18` library documentation.

---

## 9. Hierarchical Area Review

The supplied hierarchy report identifies the following area figures:

| Block | Instances | Reported area | Share of total |
|---|---:|---:|---:|
| `u_mask` / `request_mask` | 4 | 53.222 | 1.70% |
| `u_wait_counter` / `wait_counter` | 33 | 911.434 | 29.12% |
| Remaining top-level/mapped logic, calculated remainder | 111 | 2165.486 | 69.18% |
| **Total** | **148** | **3130.142** | **100.00%** |

The remaining logic values are calculated by subtracting the two listed submodules from the total. They are not a separately named hierarchy instance in the supplied report.

### Main observation

The `wait_counter` block accounts for approximately **29.12%** of total cell area, while the request mask accounts for approximately **1.70%**. The remainder includes the top-level logic and any logic not represented as those two named hierarchy blocks in the report.

### Optimization priorities

1. Review the wait-counter width and required counting range.
2. Confirm saturation, clear, hold, and independent-lane behavior before modifying counter logic.
3. Inspect the round-robin selection and owner-control path for logic depth.
4. Avoid deleting state or altering fairness behavior solely to reduce area.
5. Re-run the full testbench and compare synthesis reports after any RTL change.

---

## 10. Power Analysis

The supplied power report gives the following values for `round_robin_arbiter`.

### Power by category

| Category | Reported power | Share |
|---|---:|---:|
| Register | 154.535 µW | 66.83% |
| Logic | 62.6508 µW | 27.10% |
| Clock | 14.0405 µW | 6.07% |
| **Total** | **231.226 µW** | **100.00% approximately** |

### Internal, switching, and leakage power

| Component | Reported power | Share |
|---|---:|---:|
| Internal | 180.134 µW | 77.90% |
| Switching | 50.9991 µW | 22.06% |
| Leakage | 0.0934524 µW | 0.04% |
| **Total** | **231.226 µW** | **100.00% approximately** |

### Interpretation

- Register-category power is the largest reported category.
- Internal power is the largest component of the total estimate.
- Switching power depends on signal activity and capacitive loading.
- Leakage is small in this report, but its value depends on the library and operating conditions.
- The report is an estimate, not a direct silicon measurement. The supplied summary does not establish post-route parasitics or a complete physical clock-tree implementation.

For a meaningful before/after comparison, use the same constraints, library, operating conditions, activity assumptions, and analysis settings.

---

## 11. Timing Analysis

The supplied timing report contains a setup path marked **MET**.

| Timing item | Reported value |
|---|---|
| Reported setup slack | **+2278 ps (+2.278 ns)** |
| Startpoint | `fault` |
| Endpoint | `u_owner_state_reg[1]/SE` |
| Endpoint cell | `SDFFRHQX1` |
| Clock period | 10 ns |
| Setup value shown | 796 ps |
| Clock uncertainty | 1000 ps |
| Input delay | 1000 ps |
| Data-path delay | 4926 ps (4.926 ns) |
| Arrival time | 5926 ps |
| Required time | 8204 ps |
| Reported path status | MET |

### Timing interpretation

- The selected path has a reported positive setup slack of 2.278 ns.
- This is evidence that **this reported path** meets its setup requirement under the report's assumptions.
- A single MET path does not establish that every setup and hold path is constrained and passing.
- The endpoint pin is reported as `SE`. Since pin naming and semantics are library-specific, confirm the exact pin function in the cell library and inspect the complete timing report before interpreting it as a conventional data pin.
- The report's path includes a combinational logic chain; optimize based on the actual critical-path report rather than cell area alone.

### Required timing checks

1. Review the complete timing summary, including worst setup slack and worst hold slack.
2. Confirm all relevant clocks and input/output constraints.
3. Check for unconstrained endpoints and paths.
4. Verify the meaning of the `SE` endpoint pin in the target library.
5. Inspect timing exceptions and ensure they are justified by the design.
6. Re-run timing analysis after any RTL or constraint change.

**Timing closure for the complete design is not established by this single path report.**

---

## 12. Recommended Optimization Plan

| Priority | Investigation | Reason |
|---:|---|---|
| 1 | Review `wait_counter` implementation | It accounts for about 29.12% of reported cell area. |
| 2 | Inspect owner-control and selection timing | The reported timing path begins at `fault` and ends at an owner-state cell pin. |
| 3 | Validate all timing constraints | A single MET path cannot prove full timing closure. |
| 4 | Review power activity assumptions | Power is an estimate and depends on stimulus and analysis settings. |
| 5 | Preserve fairness and fault/resource behavior | Optimization must not change arbitration semantics. |
| 6 | Re-run the actual testbench | Confirm functional correctness after RTL changes. |
| 7 | Re-run Genus and compare reports | Use consistent conditions for area, power, and timing comparisons. |

---

## 13. Overall Results Summary

| Metric | Result | Qualification |
|---|---|---|
| Test-log status | 500 PASS entries / 0 reported failures | One PASS record is unlabeled in the visible log |
| Scenario groups | Aging, selector, owner control, wait counter, top-level | Reported group-completion messages |
| Testbench completion | `$finish` at 70006 NS | Transcript also says an installed-simulator run is still required |
| Mapped cell count | 148 | Genus synthesis report |
| Reported cell area | 3130.142 area units | Physical unit not confirmed |
| Estimated total power | 231.226 µW | Power-report estimate |
| Largest named submodule area | `wait_counter` | 911.434 area units |
| Reported setup slack | +2.278 ns | One path marked MET |
| Full setup/hold closure | Not established | Complete constrained timing summary required |
| Post-route PPA closure | Not established | Physical implementation evidence not supplied |
| Formal proof / safety certification | Not established | Not claimed by the test log |

---

## 14. Suggested Repository Structure

```text
day27-round-robin-arbiter/
├── README.md
├── rtl/
│   ├── round_robin_arbiter.v
│   ├── request_mask.v
│   └── wait_counter.v
├── tb/
│   └── day27_tb.v
├── sim/
│   ├── simulation.log
│   └── waves.shm/
├── genus/
│   ├── constraints.sdc
│   ├── reports/
│   │   ├── hierarchy.rpt
│   │   ├── area.rpt
│   │   ├── power.rpt
│   │   └── timing.rpt
│   ├── mapped_netlist.v
│   └── synthesis.log
└── docs/
    └── ppa_analysis.md
```

This is a suggested structure, not a claim that every listed file exists. Update filenames and retain only the artifacts present in the actual repository.

---

## 15. Industry Relevance

This project demonstrates concepts relevant to:

- Synthesizable Verilog RTL.
- Round-robin arbitration and resource sharing.
- Request masking and grant control.
- Counter design and saturation behavior.
- Control-state verification.
- Self-checking testbench analysis.
- Cadence NCSim simulation workflows.
- Cadence Genus synthesis and technology mapping.
- Standard-cell and hierarchical area analysis.
- Power-report interpretation.
- Timing constraints and setup-path review.
- Engineering documentation and evidence-based PPA reporting.

These topics are relevant to entry-level RTL Design, ASIC Design, Design Verification, FPGA Design, and Digital VLSI roles.

---

## 16. Interview Questions

1. What problem does an arbiter solve in a digital system?
2. How does round-robin arbitration differ from fixed-priority arbitration?
3. What is the purpose of a priority pointer?
4. How can an arbiter avoid starvation?
5. What is request masking, and when might it be used?
6. Why should the grant signal remain consistent with the owner state?
7. How would you verify round-robin progression under continuous competing requests?
8. What is the difference between a counter that wraps and a saturating counter?
9. How would you test reset, hold, clear, and saturation behavior?
10. What is technology mapping?
11. Why can a block with few instances still have a significant area contribution?
12. What is the difference between internal, switching, and leakage power?
13. What does positive setup slack mean?
14. Why does one MET path not prove timing closure?
15. Why must the reported endpoint pin be checked against the library?
16. How would you investigate an unconstrained timing path?
17. What evidence is needed before claiming post-route PPA closure?
18. Why should functional tests be rerun after area or timing optimization?

---

## 17. Project Status

| Stage | Status |
|---|---|
| Test-log review | 500 PASS statuses and 0 reported failures |
| Fresh simulator reproduction | **Needs confirmation** because the log itself contains a note requesting an installed-simulator run |
| Hierarchy report | Reviewed |
| Standard-cell area report | Reviewed |
| Hierarchical area report | Reviewed |
| Power report | Reviewed; estimate assumptions should be documented |
| Selected timing path | Reviewed; one path marked MET with +2.278 ns slack |
| Full setup/hold timing closure | Not established |
| Post-route physical implementation | Not established |
| Final PPA closure | Pending complete constraints and physical-design evidence |

---

## 18. Author

**Omkar Kalmesh Hadapad**  
Electronics and Communication Engineering

Digital VLSI · Verilog RTL · Functional Verification · Cadence Genus

---

<p align="center">
  <b>Day 27 — Round-Robin Arbiter Design, Verification and Synthesis Analysis</b>
</p>
'''
