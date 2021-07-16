import 'package:sudoku_crypto/src/models/sudoku.dart';
import 'package:sudoku_crypto/src/models/database.dart';
import 'package:sudoku_crypto/src/blocs/current_sudoku.dart';
import 'package:sudoku_crypto/src/blocs/database_state.dart';
import 'package:sudoku_crypto/src/resources/communications.dart';
/*
  sending data using the packet handler class:
  test.send
*/
import 'dart:convert';
import 'dart:io';

//Main class that will be globally accessible
class AppEngine {
  static List<List<int>> testGrid = [
    [1, 2, 3, 4, 5, 6, 7, 8, 0],
    [4, 5, 6, 7, 8, 9, 1, 2, 3],
    [7, 8, 9, 1, 2, 3, 4, 5, 6],
    [2, 3, 1, 5, 6, 4, 8, 9, 7],
    [5, 6, 4, 8, 9, 7, 2, 3, 1],
    [8, 9, 7, 2, 3, 1, 5, 6, 4],
    [3, 1, 2, 6, 4, 5, 9, 7, 8],
    [6, 4, 5, 9, 7, 8, 3, 1, 2],
    [9, 7, 8, 3, 1, 2, 6, 4, 5]
  ];
  String myName = "Test";

  //To hold all the database data
  SudokuDatabase database = SudokuDatabase();
  //To hold the user's solution of the database
  Sudoku _currentSudoku = Sudoku(sudokuID: 0, grid: testGrid);
  set currentSudoku (Sudoku s){
    _currentSudoku = s;
    sudokuBLoC.updatedSudoku();
  }
  Sudoku get currentSudoku => _currentSudoku;
  //To hold the original sudoku problem received from the server
  Sudoku _problemSudoku = Sudoku(sudokuID: 0, grid: testGrid);
  set problemSudoku (Sudoku s){
    _problemSudoku = s;
    sudokuBLoC.newSudoku();
  }
  Sudoku get problemSudoku => _problemSudoku;
  //To update the UI when the sudoku is changed by the user or server
  SudokuBLoC sudokuBLoC = SudokuBLoC();
  //To update the UI when the database changes
  DatabaseStateBLoC databaseStateBLoC = DatabaseStateBLoC();
  //To communicate with the server
  //TODO: Make the communications class with all the required function members
  PacketHandler comms = PacketHandler(destIpString: "192.168.4.1", portNumber: 50000);
  void onData(RawSocketEvent event) async {
    // and event handler for when a packet is received
    print("socket event");
    if (event == RawSocketEvent.read) {
      Datagram? rcv = comms.socketConnection.receive();
      List<int> data = [];
      for (int i = 0; i < rcv!.data.length; i++){
        if (rcv.data[i] < 127) data.add(rcv.data[i]);
      }
      print("Received data: " + ascii.decode(data));
      PacketSplitter pcktReceived = PacketSplitter(ascii.decode(data));
      if (pcktReceived.type == "0") {
        //the MCU is updating the sudoku
        //TODO CONFIRM SUDOKUS ARE THE SAME ; ACCESS A STRING REPRESENTATIOON OF THE SUDOKU
        //RECEIVED USING COMMAND pcktReceived.sudoku;
        if (problemSudoku.sudokuID != pcktReceived.sudoku.hashCode) {
          problemSudoku = Sudoku(
              sudokuID: pcktReceived.sudoku.hashCode,
              grid: pcktReceived.sudokuTable
          );
          currentSudoku = Sudoku(
              sudokuID: pcktReceived.sudoku.hashCode,
              grid: pcktReceived.sudokuTable
          );
        }
      }
      else if (pcktReceived.type == "2") {
        //someone has completed the sudoku and won
        //TODO Update the database
        //access the person who solved with pcktReceived.solver the old sudoku id is pckreceive.id
        await database.updateDatabase(
            pcktReceived.sudoku.hashCode, pcktReceived.solver
        );
        databaseStateBLoC.newDatabaseEntry();

        List<Player> players = await database.players();
        print ("Player's database: " + players.toString());

        List<Log> logs = await database.logs();
        print ("Log's database: " + logs.toString());
      }
      else if (pcktReceived.type == "3") {
        this.problemSudoku = Sudoku(
            sudokuID: pcktReceived.sudoku.hashCode, grid: pcktReceived.sudokuTable
        );
        this.currentSudoku = Sudoku(
            sudokuID: pcktReceived.sudoku.hashCode, grid: pcktReceived.sudokuTable
        );
      }
    }
  }

  int _selectedNumberID = 0;
  set selectedNumberID(int s) {
    _selectedNumberID = s;
    sudokuBLoC.updatedSudoku();
  }
  int get selectedNumberID => _selectedNumberID;

  AppEngine() {
    //Initializer for the class
  }

  void dispose() {
    //Deconstructor for the class
    sudokuBLoC.dispose();
    databaseStateBLoC.dispose();
  }

  void initializeAppEngine () async {
    await comms.initializeIp();
    comms.socketConnection.listen(onData);
    await database.initializeDatabase();
  }

  String encapsulateData() {
    //encapsulate data to send
    String pckt = "";
    pckt = "1" + currentSudoku.toString() + myName;
    return pckt;
  }

  void setNumber(int number) {
    int row = (selectedNumberID / 9).truncate();
    int column = selectedNumberID % 9;
    if (this.problemSudoku.grid[row][column] == 0) {
      this.currentSudoku.grid[row][column] = number;
      sudokuBLoC.updatedSudoku();
    }
  }

  bool checkSudokuComplete(Sudoku sudoku) {
    //TODO: Write code for checking if the sudoku is complete (all numbers present)

    return false;
  }

  bool check_SudokuCorrectness() {
    //TODO: Write code for checking if complete sudoku is correct
    if (currentSudoku.checkSudokuCorrectness()) {
      String pckt = encapsulateData();
      print("Packet to send: $pckt");
      comms.sendData(pckt);
      return true;
    }
    return false;
  }
}
