# Converter control models (Simulink, ideal switches)

Three power-converter models for reviewing the control design. They were translated from
PLECS into plain Simulink so they simulate faster:

| folder | model | converter |
|---|---|---|
| `dab/` | `dab_fpga.slx` | Dual active bridge, 700 V → 250 V, 150 kHz phase-shift modulation |
| `classd/` | `classd_revb.slx` | Class D amplifier: six interleaved half bridges on a 400 V bus, 33.3 kHz |
| `sixswitch/` | `sixswitch.slx` | Three-phase active rectifier (380 V grid → 700 V DC), dq current control, 100 kHz SVPWM |

## Requirements

* MATLAB with **Simulink**, **R2024b or later**. No other toolbox is needed (no Simscape).
* If you have an older release, ask for the models to be exported for it.

## Running a model

1. Unzip anywhere, keeping the folder structure.
2. Open the `.slx` file, for example by double-clicking `dab/dab_fpga.slx`.
3. Press **Run**.

When the simulation starts, the model loads its own parameters: its InitFcn runs the
`*_params.m` script in the same folder. You don't need to load anything or set a path.
Results appear in the scopes on the top level of each model, and the outputs are returned
in `out.yout`.

To run from the command line, use the model's own stop time or a shorter window:

```matlab
open_system('dab/dab_fpga.slx');
out = sim('dab_fpga', 'StopTime', '2e-3');
```

## Changing parameters

**Edit the `*_params.m` file next to the model, save it and run again.** Changes made in
block dialogs or in the base workspace are overwritten, because the params script runs at
every start.

The positions of the original PLECS manual switches are the `sel_*` variables near the top
of the "Translation-specific settings" section of each params file. Position 1 is the upper
input of the switch.

### DAB (`dab/dab_params.m`)

* **Control path:**
  1. `Vref − Vo` goes through a Periodic Average over 2 switching periods.
  2. A PI follows: `dab_pid.kp = 0.125`, `ki = 0.002`, initial value 0.25, limits ±0.49,
     back-calculation anti-windup.
  3. The PI output × 0.5 gives the phase shift φ.
  4. Dp/Ds scheduling (`Force`, `Dp`, `Ds`, `tps*`) sets the inner phase shifts
     α = (1 − D)/2.
  5. The FPGA-style phase-shift PWM has a 100 ns turn-on delay (`DeadTime`).
* **Switches:**
  * `sel_vref`: Vout target or ramp;
  * `sel_power`: power target or test source;
  * `sel_startup`;
  * `sel_alphaP` / `sel_alphaS`: `(1−D)/2` or the C-Script.
* **Operating point:** `Vin = 700`, `Vout = 250`, load `Pout = 16000` W, stop time 4 ms
  (`timeSpan`).

### Class D (`classd/classd_params.m`)

* **Demand:**
  * `sel_ms = 1` is a 4 Hz → 10 kHz sine sweep over `Timespan`;
  * `sel_ms = 2` with `sel_ms2 = 2` is a 567.2 Hz sine;
  * the demand is scaled by `sel_ms4`.
* **Current loops (`ipid.*`):**
  * PI, `kp = 0.005`, `ki = 10`, sampled at 2 MHz, output ±1;
  * one PI per leg pair, acting on `demand/3 − (Ip − In)/2`.
* **Voltage-feedback path:** `sel_ipid = 2`, with `vfb.*`.
* **Modulation:** 3-state PWM at 33.3 kHz, carriers interleaved by T/3, 500 ns turn-on
  delay (`tdead`).
* **Load:** `sel_load`. 3 is a 0.19 Ω field resistance.
* **Leg inductors:** `Lleg`, 75 µH per leg (see the notes below).
* **Stop time:** 1 s (`Timespan`), long enough for the whole sweep.

### SixSwitch (`sixswitch/sixswitch_params.m`)

* **DC voltage loop (`vc.*`):**
  * a Moving Average over 10 switching periods;
  * then a PI, `kp = 0.25`, `ki = 160`, at 100 kHz, output −32…40 A, which gives id*;
  * `sel_idref` swaps in a constant id*.
* **Current loops (`cc.*`):**
  * PI, `kp = 3.5`, `ki = 125`;
  * ωL decoupling on the d axis (`sel_dec_d`);
  * `sel_q` selects the q-axis PI (2) or a constant −1.85 V (1, as saved).
* **PLL (`pll.*`):** an SRF-PLL with ωn = 2π·25 rad/s and ζ = 0.707.
* **Load:**
  * `sel_load = 2` ramps from 100 W to 18 kW starting at 50 ms (`load_ramp_*`);
  * `sel_load = 1` is 440 Ω plus pulsed 100 Ω loads.
* **Stop time:** 1 s.

## Run times

Wall-clock times on the author's PC (MATLAB R2024b). The first run of a session adds a few
seconds of compilation.

| model | simulated time | wall clock |
|---|---|---|
| DAB | 4 ms (full run) | ≈ 7 s |
| Class D | 20 ms | ≈ 6 s |
| SixSwitch | 25 ms | ≈ 4 s |
| Class D | 1 s (full sweep) | ≈ 3 min |
| SixSwitch | 1 s (full run, load ramp to 18 kW) | ≈ 1.5 min |

To look at a short window, set a smaller stop time in the toolbar.

## What the models include and leave out

* **Ideal switches:**
  * zero on-resistance, instant switching;
  * during dead time each leg is clamped by the anti-parallel diode selected by the sign of
    its current;
  * every switching instant is located exactly by zero-crossing detection (variable-step
    solver `ode23tb`).
* **The power stage of each model** is a MATLAB Function block (`*_plant`) holding the
  circuit equations. `*_plant.m` is a readable copy of the same code.
  * The params script calls it once for the initial measurements.
  * Editing the `.m` file does **not** change the block.
* **The control** is built from ordinary Simulink blocks and laid out like the PLECS
  schematics, with the same block names where possible.
* **Left out:**
  * thermal and loss models;
  * snubbers, device capacitances and gate resistors;
  * THD meters;
  * the small-signal analysis blocks;
  * the DAB triple-phase-shift modulator, an unused alternative in PLECS.

## Known points to be aware of

These come from the original PLECS models, not from the translation. They are reproduced as
saved, or noted where they differ:

* **DAB transformer leakage is counted twice.** The transformer block carries 13 µH of
  internal leakage on each side, on top of the external leakage inductors.
  * The series inductance is therefore ≈ 118 µH referred to the primary, so the bridge can
    move only ≈ 3–3.5 kW.
  * Under the 16 kW load the PI saturates at φ = 0.245 and Vo sags from 250 V to ≈ 238 V.
  * To try zero internal leakage, set `dab_tx.Lp = 0; dab_tx.Ls = 0;`.
* **Class D leg inductance differs from the PLECS file.** The PLECS file is saved with
  0.2 nH legs, which gives unlimited circulating current with ideal switches. These models
  use 75 µH per leg (the "No Mutual Inductance" option), which still leaves ≈ ±20–25 A of
  circulating ripple between the uncoupled interleaved legs.
* **SixSwitch q-axis loop is open as saved.** The q-axis PI is bypassed by a constant
  (`sel_q = 1`).
  * At start-up, Vdc overshoots to ≈ 980 V while the PLL locks, and iq drifts to ≈ −60 A
    by 25 ms.
  * With `sel_q = 2`, Vdc holds at 700 V and the currents stay near zero at light load.
* **SixSwitch PLL is a replacement.** The PLECS "Three-Phase PLL" library block was
  replaced by a standard SRF-PLL, so the start-up transient will differ somewhat from PLECS.

## Validation status

* **Checked:** each model has been simulated in MATLAB R2024b, and the results agree with
  an independent check of the translated equations.
* **Not yet done:** a waveform-by-waveform comparison against the original PLECS models.
* **Assumptions still to confirm against PLECS:**
  * manual switch position 1 is the upper input;
  * the PLECS PID anti-windup options;
  * Periodic Average holds the last period's mean;
  * sine phase units are degrees.
