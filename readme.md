# RISC-V UART Debugger #

### About ###
Control and debug a RISC-V MCU over USB UART.

Configured by default for a 50 MHz CPU communicating with a baud rate of 115200. This can be adjusted by changing the BAUD definion in client/src/serial.h and the BAUD/CLK_RATE parameters of the mcu_controller module.

### Client installation ###

The best way is to build and install from source:

```
git clone git@github.com:trmckay/riscv-uart-debugger.git
cd riscv-uart-debugger/client
./INSTALL
```

### Usage ###
Launch the tool with:
```
uart-db <device>
```
Or to autodetect ports, omit the device.

Your device is likely connected to /dev/ttyUSBX or /dev/ttySX.
Once in the tool, type 'h' or 'help' for more information.

### Protocol implementation ###
Documentation source be built with pdflatex or your choice of LaTeX compiler. Prebuilt PDFs can also be found in the releases.

Implement the protocol as defined in the doc on your MCU. Then, add the proper constraints to
forward your UART tx/sx connections to the mcu\_controller module.
