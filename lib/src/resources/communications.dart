import 'dart:async';
import 'dart:convert';

import 'dart:io';

void main() async {
  //This is a demo code to show sending of data and it's reception using UDP
  // ****This code is not meant to be run using flutter
  // ****To run the code open a terminal and call:
  //        dart communications.dart
  PacketHandler test = PacketHandler(destIpString: "192.168.43.235", portNumber: 50000);
  //String totest = "1123456432345543";
  //packet_splitter test1 = packet_splitter(totest);
  await test.initializeIp();
  await Future.delayed(Duration(seconds: 1));
  while (true) {
    test.sendData("");
  }
}

class PacketHandler {
  int portNumber;
  String destIpString;
  late RawDatagramSocket
      socketConnection; //the socket connection that will be carrying out the udp message sending

  PacketHandler({required String this.destIpString, required int this.portNumber});

  Future<void> initializeIp() async {
    this.socketConnection =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, this.portNumber);
    print('got here $this.socketConnection');
    print("The socket is connected to: ${socketConnection.address}:" +
        this.socketConnection.port.toString());
    List<NetworkInterface> ni = await NetworkInterface.list();
    print("The internet address is: ${ni[0].addresses[0].address}");

    print("The IP address the socket will connect to is ${this.destIpString}:${this.portNumber}");
  }

  void sendData(String stringToSend) {
    List<int> buffer = ascii.encode(stringToSend);
    InternetAddress destAddress = InternetAddress(this.destIpString);
    socketConnection.send(buffer, destAddress, this.portNumber);
    print("The string '$stringToSend' has been sent.");
    //We need a delay to allow the main thread with input to hand over control of the terminal
    //  to the listen thread so that it can output to console
    //await Future.delayed(Duration(seconds: 1));
  }
}

class PacketSplitter {
  String? type;
  String sudoku = "";
  List<List<int>> sudokuTable = [];
  String solver = "";
  PacketSplitter(String packet) {
    assert(packet.length > 81);
    type = packet.substring(0, 1);
    if (type == "0") {
      //this is a packet containing the current sudoku only
      this.sudoku = packet.substring(1, 82);
    } else if (type == "2") {
      // this is a packet containing the sudoku that has been solved and the person who solved it
      this.sudoku = packet.substring(1, 82);
      this.solver = packet.substring(82, packet.length);
    } else if (type == "3") {
      this.sudoku = packet.substring(1, 82);
    } else {
      //this is not a packet that has been received and thus should not be sent; We shouldn't get here;
      assert(false);
    }
    for (int i = 0; i < 81; i = i + 9) {
      List<int> list1 = [];
      for (int j = 0; j < 9; j++) {
        int a = int.parse(this.sudoku[i + j]);
        list1.add(a);
      }
      this.sudokuTable.add(list1);
    }
  }
}
