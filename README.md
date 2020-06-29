# BasicUART
Small light-weight implementation of UART transmitter and receiver in Verilog. It uses fixed serial data format 8-N-1 (8 data bits, 1 stop bit, without parity check and without hardware flow control). Baud rate can be parametrized from arbitrary low value up to 1/3 of base top level clock. On tested FPGA (from iCE40 family) each of the modules uses about 40 LUTs. Modules use only generic Verilog so they can be use on virtually any FPGA. 

Design was tested on board TinyFPGA-BX which uses ICE40LP8K FPGA. It was successfully synthesized in both open source toolchain APIO (uses Icarus Verilog) and proprietary Lattice iCEcube2 toolchain. Serial communication was tested with USB-to-Serial adapter based on CP21O4 chip on speeds from 300 to 2 000 000 bauds.


## Serial transmitter


```verilog
module SerialTransmitter
  #(
    parameter ClockFrequency = 16000000,  // Base clock frequency of your design in Hz
    parameter BaudRate       = 115200     // Required baudrate (9600, 115200, 2000000, ...) can be max 1/3 of ClockFrequency
  )
  (
    input  wire       iClock,      // Top level clock with frequency specified in ClockFrequency parameter
    input  wire [7:0] iData,       // Byte of data to send
    input  wire       iSend,       // Assert for at least one clock cycle for start sending contents of iData
    output reg        oReady = 0,  // Signalizes readiness to take over next byte to send
    output reg        oTXD         // UART transmit pin
);
```
Parameters ClockFrequency and BaudRate set to requirements of your design. BaudRate can be max 1/3 of ClockFrequency. Connect top level clock (on frequency in parameter ClockFrequency) to iClock. Output serial signal is available on oTXD. 

For send a byte value set iData to required value and assert iSend for at least one clock cycle. The module takes over data into own buffer and starts transmitting. The iData value has to be valid only for first cycle when iSend is asserted then inner buffer of module is used.

The signal oReady indicates readiness to take over next byte for send. Module set the signal to 0 after take over data to send and during transmitting the start and data bits. After last data bit sent the oReady signal is immediatelly set to 1 so next byte to send can be pass already during transmitting stop bit of previous byte. Because of that there is not any delay before transmitting next byte.


## Serial receiver

```verilog
module SerialReceiver
  #(
    parameter ClockFrequency = 16000000,  // Top level clock frequency (set for frequency used by your desing)
    parameter BaudRate       = 115200     // Set to required baud rate (9600, 115200, ...) can be max 1/3 of ClockFrequency
  )
  (
    input  wire       iClock,             // To level Clock used frequency specified in ClockFrequency parameter
    input  wire       iRXD,               // Serial data input with baud rate specified in BaudRate parameter
    output reg  [7:0] oData,              // Received data byte
    output reg        oReceived = 0,      // Signalizes (for one clock) received valid data in oData
    output reg        oError    = 0       // Signalizes (for one clock) error in receiving data (missing stop bit)
);

```

Parameters ClockFrequency and BaudRate set to requirements of your design. BaudRate can be max 1/3 of ClockFrequency (but it is recommended greater ratio) Receiving serial line is connected to iRXD. Top level clock of your design is connected to iClock.

  Each time receiver receives one valid frame (byte) it makes it available on oData and set oReceived for one clock. If an error (missing stop bit) occurs in receiving data oError is set for one clock.


## License
Design is provided under MIT license.  
