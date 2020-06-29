/*

  Basic serial transmitter (UART)
  Designed by Stanislav Jurny 6.2020

  Serial data format is 8 data bits, without parity, one stop bit (8N1) without hardware flow control.
  Please set up parameters ClockFrequency and BaudRate to requirements of your design. BaudRate can be max 1/3 of ClockFrequency.

  Connect top level clock (on frequency in parameter ClockFrequency) to iClock. Output serial signal is on oTXD.
  For send a byte value set iData to required value and assert iSend for at least one clock cycle. The module
  takes over data into own buffer and starts transmitting. The iData value has to be valid only for first cycle
  when iSend is asserted.  The signal oReady indicates readiness to take over next byte for send. The signal is
  set to 0 after take over data to send and during transmitting the start and data bits. After last data bit sent
  the oReady signal is immediatelly set to 1 so next byte to send can be pass already during transmitting
  stop bit of previous byte. Because of that there is not any delay before transmitting next byte.

  This design is provided under MIT license

  -----------------------------------------------------------------

  Copyright (c) 2006 Stanislav Jurny (github.com/STjurny)

  Permission is hereby granted, free of charge, to any person
  obtaining a copy of this software and associated documentation
  files (the "Software"), to deal in the Software without
  restriction, including without limitation the rights to use,
  copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the
  Software is furnished to do so, subject to the following
  conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
  OTHER DEALINGS IN THE SOFTWARE.

*/
module SerialTransmitter
  #(
    parameter ClockFrequency = 16000000,  // Top level clock frequency (set for frequency used by your desing)
    parameter BaudRate       = 115200     // Set to required baudrate (9600, 115200, 2000000, ...) can be max 1/3 of ClockFrequency
  )
  (
    input  wire       iClock,      // Top level clock with frequency specified in ClockFrequency parameter
    input  wire [7:0] iData,       // Byte of data to send
    input  wire       iSend,       // Assert for at least one clock cycle for start sending contents of iData
    output reg        oReady = 0,  // Signalizes readiness to take over next byte to send
    output reg        oTXD         // UART transmit pin
  );


  localparam
    TicksPerBit = ClockFrequency / BaudRate,
    TimerMSB = $clog2(TicksPerBit) - 1,
    LastTickOfBit = TicksPerBit - 1;

  initial
    begin
      $display("UART transmitter summary");
      $display("TicksPerBit = %d", TicksPerBit);
      $display("TimerMSB = %d", TimerMSB);
      $display("LastTickOfBit = %d", LastTickOfBit);
    end


  localparam
    sIdle     = 0,
    sStartBit = 1,
    sDataBit  = 2,
    sStopBit  = 3;


  reg [1:0]        State    = sIdle;
  reg [TimerMSB:0] Timer    = 0;
  reg              BitSent  = 0;

  always @(posedge iClock)
    if (State == sIdle || BitSent)
      Timer <= 0;
    else
      Timer <= Timer + 1;

  always @(posedge iClock)  // comparison is potentially complex so we do it separately one clock earlier
    BitSent <= Timer == LastTickOfBit[TimerMSB:0] - 1;


  reg [2:0] BitIndex = 0;
  reg [7:0] Buffer;

  always @(posedge iClock)
    case (State)
      sIdle:
        if (iSend)
          begin
            Buffer <= iData;
            oReady = 0;         // it intentionally uses blocking assignment
            State <= sStartBit;
          end
        else
          oReady = 1;           // it intentionally uses blocking assignment

      sStartBit:
        if (BitSent)
          State <= sDataBit;

      sDataBit:
        if (BitSent)
          begin
            Buffer <= {1'b0, Buffer[7:1]};  // shift buffer right for send next bit
            BitIndex <= BitIndex + 1;

            if (BitIndex == 7)
              begin
                oReady = 1;         // it intentionally uses blocking assignment
                State <= sStopBit;
              end;
          end

      sStopBit:
        begin
          if (oReady && iSend)  // next byte to send can be set before sending of stop bit is completed
            begin               // so there isn't any delay before beginning of sending next byte
              Buffer <= iData;
              oReady = 0;       // it intentionally uses blocking assignment
            end;

          if (BitSent)
            if (~oReady)
              State <= sStartBit;
            else
              State <= sIdle;
        end
    endcase


  always @(posedge iClock)  // registered output prevents glitches but delay TXD one cycle after State
    oTXD <=
      State == sIdle ||
      State == sStopBit ||
      State == sDataBit && Buffer[0];  // LSB is sending bit


endmodule


















