# BasicUART
Small light-weight implementation of UART in Verilog. It uses fixed serial data format 8-N-1 (8 data bits, 1 stop bit, without parity check and without hardware flow control). Baud rate can be parametrized from arbitrary low value up to 1/3 of system clock. On tested FPGA (from iCE40 family) each of the modules uses about 40 LUTs. The modules use only generic Verilog so they can be used on virtually any FPGA. 

The design was tested on board [TinyFPGA-BX](https://tinyfpga.com) which uses ICE40LP8K FPGA. It is synthesizable in open source toolchain [APIO](https://github.com/FPGAwars/apio)/[IceStorm](http://www.clifford.at/icestorm) same as in proprietary toolchain iCEcube2 from Lattice. Serial communication was tested with USB-to-Serial adapter based on CP2104 chip on speeds from 300 to 2 000 000 bauds.


## Serial Transmitter


```verilog
module SerialTransmitter
  #(
    parameter ClockFrequency = 16000000,  // System clock frequency in Hz
    parameter BaudRate       = 115200     // Required baudrate (9600, 115200, ...)
  )
  (
    input  wire       iClock,  // System clock input
    input  wire [7:0] iData,   // The data to be sent
    input  wire       iSend,   // Assert for send data in iData 
    output reg        oReady,  // Readiness to take over next byte to send
    output reg        oTXD     // UART transmit pin
);
```
Set parameters `ClockFrequency` to frequency of your system clock and `BaudRate` to requirements of your design. `BaudRate` can be max 1/3 of `ClockFrequency`.  

For send a byte value set `iData` to required value and set `iSend` to `1` for at least one clock cycle. The module takes over data into own buffer and starts transmitting. 

The signal `oReady` indicates readiness to take over next byte for send. Module set the signal to `0` after take over data to send and during transmitting the start and data bits. After last data bit sent the `oReady` signal is immediatelly set to `1` so next byte to send can be pass already during transmitting stop bit of previous byte. Because of that there is not any delay before transmitting next byte.


## Serial Receiver

```verilog
module SerialReceiver
  #(
    parameter ClockFrequency = 16000000,  // System clock frequency in Hz
    parameter BaudRate       = 115200     // Required baud rate (9600, 115200, ...) 
  )
  (
    input  wire       iClock,     // System clock input
    input  wire       iRXD,       // UART receive pin
    output reg  [7:0] oData,      // Received data byte
    output reg        oReceived,  // Signalizes (for one clock) received valid data in oData
    output reg        oError      // Signalizes (for one clock) break or error 
);

```

Set parameters `ClockFrequency` to frequency of your system clock and `BaudRate` to requirements of your design. `BaudRate` can be max 1/3 of `ClockFrequency` (but it is recommended greater ratio). Design was succesfully tested with ratio 1/8 where `ClockFrequency=16000000` and `BaudRate=2000000`.

  Each time receiver receives one valid frame (byte) it makes it available on `oData` and set `oReceived` to `1` for one clock. If a break or error occurs in receiving data `oError` is set to `1` for one clock.


## License
Design is provided under MIT license.  
