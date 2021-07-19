import 'dart:async';

class DatabaseStateBLoC {

  //When a new database entry is received, an arbitrary int can be pushed into
  //  this stream controller to tell the UI to update
  final StreamController<int> _databaseStateController = StreamController<int>.broadcast();

  //UI elements will listen to the stream to know when the database state has changed
  late Stream<int> outDatabase;

  DatabaseStateBLoC() {
    //Initializer of the class
    outDatabase = _databaseStateController.stream;
  }

  void dispose(){
    //Deconstructor of the class
    //closing socket so that we can prevent memory leaks
    _databaseStateController.close();
  }

  void newDatabaseEntry () {
    //When a new database entry is received from the server
    //Adding an arbitrary integer to the stream controller
    _databaseStateController.add(1);
  }
}