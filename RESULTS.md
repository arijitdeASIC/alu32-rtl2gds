# Results Summary — 32-bit ALU RTL-to-GDSII

Detailed metrics from each stage of the flow. All numbers are tool-generated
(Synopsys DC / ICC2), captured from the report files in `reports/`.

---

## Synthesis (Design Compiler)

| Metric | Value |
|---|---|
| Clock target | 625 MHz (1.60 ns) |
| Setup WNS | 0.00 ns (met) |
| Setup TNS | 0.00 ns |
| Hold WNS | 0.00 ns |
| Violating paths | 0 |
| Cell count | 1,968 |
| Total cell area | 5,043 µm² |
| Vt libraries | RVT + HVT + LVT (multi-Vt) |
| Corner | ss, 0.75 V, 125 °C |

### Clock-period exploration (Fmax sweep)

| Period | Frequency | Result |
|---|---|---|
| 2.0 ns | 500 MHz | clean, HVT-dominated (large slack) |
| 1.6 ns | 625 MHz | clean — selected as target |
| 1.5 ns | 666 MHz | -0.02 ns, 1-2 paths — structural limit |

Selected 1.6 ns for clean closure with margin.

---

## Place & Route (IC Compiler II)

### Floorplan
| Metric | Value |
|---|---|
| Core area | 7,090 µm² |
| Chip area | 8,875 µm² |
| Core utilization | 70% (target) → 63% (final w/ cells) |
| Pins | 107, auto-placed on boundary |

### Power Planning
| Metric | Value |
|---|---|
| Grid | M7/M8 top mesh + M1 std-cell rails |
| PG DRC | 0 |
| PG connectivity | 0 floating std cells / vias / terminals |
| Missing vias | 0 |

### Placement
| Metric | Value |
|---|---|
| Cells placed | 1,815 (legalized, 0 displacement) |
| Congestion overflow | 0.13% |
| Legality | passed |

### Clock Tree Synthesis
| Metric | Value |
|---|---|
| Sinks | 103 |
| Global skew | 10 ps |
| Max latency | 10 ps |
| Tree levels | 1 |
| Clock buffers | 0 (single-net tree sufficient for die size) |
| Clock DRCs | 0 |

### Routing
| Metric | Value |
|---|---|
| Total nets | 1,955 |
| Open nets | 0 |
| Routing DRCs | 0 |
| Max transition violations | 0 |
| Max capacitance violations | 0 |

### Final (post chip-finishing)
| Metric | Value |
|---|---|
| Functional cells | 1,815 |
| Filler cells | ~3,900 (SHFILL series) |
| Cell area | 4,469 µm² |
| Routing DRCs | 0 |
| PG DRCs | 0 |
| Legality | passed |

---

## Design-space note: power-grid tuning

The first routed version, using a power-grid recipe adapted directly from a
reference RISC-core flow, produced **40 DRC violations** (36 signal-routing +
4 M1 PG) because the reference strap dimensions were sized for a much larger
die and crowded the router on this small block.

Re-tuning the grid — thinner M8 straps (4.64 µm → 2.0 µm), wider pitch
(19.5 µm → 30 µm), and dropping a redundant mid-layer M2 mesh — reduced
routing congestion from **0.41% to 0.13%** and cleared **all 40 violations**
to a fully DRC-clean routed design, with no impact on timing or skew.

| | v1 (reference PG) | v2 (tuned PG) |
|---|---|---|
| Routing DRCs | 40 | 0 |
| Congestion | 0.41% | 0.13% |
| Clock skew | 10 ps | 10 ps |
| Setup WNS | +0.29 ns | +0.29 ns |

---

## Deliverables produced

- Gate-level Verilog netlist (routed)
- GDSII layout
- SDF (timing delays)
- SPEF (parasitics, max + min corners)

## Pending

- PrimeTime signoff STA (independent timing verification against SPEF)
