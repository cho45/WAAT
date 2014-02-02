WAAT (Web API Aided Transceiver)

This is CAT (Computer Aided Transceiver) server which converts CAT interface to high level Web API based on WebSocket and JSON-RPC.

## Goal for WAAT

 * Manipulate rigs easily
 * Abstraction of CAT interface

## INSTALL

### Requirements

 * ruby1.9+
   * bundler
   * foreman
 * SerialPort interface (for connecting PC to Rig)

```
ruby -v
gem install bundler
gem install foreman
```

### Server

```
git clone git@github.com:cho45/WAAT.git
cd WAAT
vim config.rb ## setup serial port and baudrate
bundle install
foreman start
```

## Protocol

WAAT wake up WebSocket server at port 51234 by default. The protocol over the WebSocket is [JSON-RPC]( http://json-rpc.org/wiki/specification ).

### Format

All protocol messages are JSON and it is compliant to JSON-RPC. Eg:


```json:Request
{ "id" : 1, "method" : "frequency", params: [7010000] }
```

```json:Response
{ "id" : 1, "result" : 3, "error" : null }
```

#### Push notification

If the rig's status has changed, WAAT server send the status immediately. `id` property in this message from server is null. Eg:

```json:Push
{ "id" : null, "result" : { … } }
```

### Method

#### status

Request to send current status of a rig.

 * params: no
 * returns: status object

Eg:

```json:Request
{ "id" : 1, "method" : "status", params: [] }
```

```json:Response
{ "id" : 1, "result" : {
  "frequency" : …,
  …
} }
```

#### frequency

Request to set frequency to specified value in param.

 * params: frequency:int(Hz)
 * returns: undefined

Eg:

```json:Request
{ "id" : 1, "method" : "frequency", params: [7010000] }
```

#### mode

 * params: mode:string('CW', 'SSB', 'AM', 'FM'…)
 * returns: undefined

#### power

 * params: power:int
 * returns: undefined

#### width

 * params: width:int
 * returns: undefined

#### noise_reduction

 * params: level:int
 * returns: undefined

#### command

Send raw command to rig.

 * params: cmd:string, params:string, read:boolean, n:int
 * returns: object

## Typically Usage

### Raspberry Pi

The default `config.rb` is for Raspberry Pi environment with TTL UART interface (/dev/ttyAMA0).

So require [setup]( http://elinux.org/RPi_Serial_Connection#Preventing_Linux_using_the_serial_port ) interface and build circuit for connecting to rig as http://lowreal.net/2014/01/22/1 .

### Connecting to Server

After wake up the server with `foreman start`, server waits WebSocket connection. So just use WebSocket object in web browser.

```js
var socket = new WebSocket('ws://raspberrypi.local:51234');
socket.onmessage = function (e) {
    var data = JSON.parse(e.data);
    console.log(data);
};
…
```


## SUPPORTED RIG

 * YAESU FT-450D

## TODO

 * Rig capability negotiation
 * More rigs support
