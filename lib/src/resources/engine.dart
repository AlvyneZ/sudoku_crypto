import 'package:sudoku_crypto/src/models/sudoku.dart';
import 'package:sudoku_crypto/src/models/database.dart';
import 'package:sudoku_crypto/src/blocs/current_sudoku.dart';
import 'package:sudoku_crypto/src/blocs/database_state.dart';
import 'package:sudoku_crypto/src/resources/communications.dart';
/*
  sending data using the packet handler class:
  test.send
*/
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
  int databaseLatestID = 0;
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
  PacketHandler comms = PacketHandler(destIpString: "192.168.4.1", portNumber: 50000);


  void onData(RawSocketEvent event) async {
    // and event handler for when a packet is received
    print("socket event");
    if (event == RawSocketEvent.read) {
      Datagram? rcv = comms.socketConnection.receive();
      List<int> data = rcv!.data;
      /*for (int i = 0; i < rcv!.data.length; i++){
        if (rcv.data[i] < 127) data.add(rcv.data[i]);
      }*/
      print("Received data: $data");
      PacketSplitter pcktReceived = PacketSplitter(data);
      if (pcktReceived.type == "0") {
        //the MCU is updating the sudoku
        //CONFIRM SUDOKUS ARE THE SAME
        //RECEIVED USING COMMAND pcktReceived.sudoku;
        if (problemSudoku.sudokuID != pcktReceived.sudokuID) {
          problemSudoku = Sudoku(
              sudokuID: pcktReceived.sudokuID,
              grid: pcktReceived.sudokuTable
          );
          currentSudoku = Sudoku(
              sudokuID: pcktReceived.sudokuID,
              grid: pcktReceived.sudokuTable
          );
        }

        Future<void> makeRequests () async {
          if (pcktReceived.sudokuID != (databaseLatestID + 1)) {
            for (int i = (databaseLatestID + 1); i < pcktReceived.sudokuID; i++) {
              comms.broadcastRequestDbEntry(i);
              await Future.delayed(Duration(milliseconds: 200));
            }
          }
          List<int> missedLogs = await database.missedLogs();
          for (int i = 0; i < missedLogs.length; i++) {
            comms.broadcastRequestDbEntry(missedLogs[i]);
            await Future.delayed(Duration(milliseconds: 200));
          }
        }
        makeRequests();
      }
      else if (pcktReceived.type == "2") {
        //someone has completed the sudoku and won
        //Update the database
        //access the person who solved with pcktReceived.solver the old sudoku id is pckreceive.id
        await database.updateDatabase(
            pcktReceived.sudokuID, pcktReceived.solver
        );
        databaseStateBLoC.newDatabaseEntry();
        databaseLatestID = await database.latestLog();
      }
      else if (pcktReceived.type == "3") {
        this.problemSudoku = Sudoku(
            sudokuID: pcktReceived.sudokuID, grid: pcktReceived.sudokuTable
        );
        this.currentSudoku = Sudoku(
            sudokuID: pcktReceived.sudokuID, grid: pcktReceived.sudokuTable
        );
      }
      else if (pcktReceived.type == "4") {
        //Database entry for synchronizing databases
        await database.updateDatabase(
            pcktReceived.sudokuID, pcktReceived.solver
        );
        databaseStateBLoC.newDatabaseEntry();
        databaseLatestID = await database.latestLog();
      }
      else if (pcktReceived.type == "5") {
        //Database entry request
        Log? log = await database.getLog(pcktReceived.sudokuID);
        if ((log != null) && (log.playerWhoSolved != "::Missed::")){
          comms.sendDbEntry(log.sudokuID, log.playerWhoSolved, rcv.address, rcv.port);
        }
      }
      //Any other type?
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
    databaseLatestID = await database.latestLog();
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
      comms.sendCompletedSudoku(currentSudoku.sudokuID, currentSudoku.toString(), myName);
      return true;
    }
    return false;
  }
}
