pragma solidity ^0.7;
//import "@nomiclabs/builder/console.sol";

contract MultiSOS {

    struct Game {
        address player1;
        address player2;
        uint32 gameID;
        string gameState;
        address nowPlaying;
        uint8 round; // number of round
        uint256 player1JoinTime;
        uint256 lastMoveTime;
        bool isPending;
    }

    address owner;
    uint256 deposit;
    uint8[][] winningTriplets = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6]
    ];
    mapping(address => uint32) playerToGameID;
    mapping(uint32 => Game) gameIDtoGame;
    uint32 totalGames = 0;
    Game lastGame;



    //Declare an Event
    event NewGame(address player1, address player2);
    event MoveEvent(address player, uint8 square, uint8 letter);

    constructor() {
        owner = msg.sender;
    }

    function getGameState() public view returns(string memory) {
        return gameIDtoGame[playerToGameID[msg.sender]].gameState;
    }

    function collectProfit() external {
        require(msg.sender == owner, "It is not your money. Only owner of the contract can call collectProfit");
        uint256 _deposit = deposit;
        deposit = 0;
        msg.sender.call{value: (_deposit)}(""); // prevent owner from hacking himself with fallback
    }

    function play() public payable {
        require(msg.value >= 1 ether, "You have to pay at least 1 ether");
        require(playerToGameID[msg.sender] == 0, "You are currently playing"); //so they cannot play twice
        if (lastGame.isPending == true) {
            lastGame.player2 = msg.sender;
            lastGame.nowPlaying = lastGame.player1;
            lastGame.isPending = false;
            playerToGameID[msg.sender] = lastGame.gameID;
            gameIDtoGame[lastGame.gameID] = lastGame;

        } else {
            lastGame = Game({
            gameState: '---------',
            round: 0,
            player1: msg.sender,
            player2: address(0),
            player1JoinTime: block.timestamp,
            gameID: ++totalGames,
            isPending: true,
            lastMoveTime: uint256(-1), //maximum integer
            nowPlaying: address(0)
            });
            playerToGameID[msg.sender] = lastGame.gameID;
            gameIDtoGame[lastGame.gameID] = lastGame;
        }
        emit NewGame(lastGame.player1, lastGame.player2);
    }

    function placeS(uint8 x) external {
        uint32 gameID = playerToGameID[msg.sender];
        place(gameID, x, 'S');
    }

    function placeO(uint8 x) external {
        uint32 gameID = playerToGameID[msg.sender];
        place(gameID, x, 'O');
    }

    function cancel() public{
        require(lastGame.player1 == (msg.sender), "You are not the 1st player");
        require(lastGame.player2 == address(0), "Player 2 has joined");
        uint256 timePassed = block.timestamp - lastGame.player1JoinTime;
        require(timePassed >= 2 minutes, "2 minutes not passed yet, be patient");
        resetGame(lastGame);
        msg.sender.call{value: (1 ether)}(""); //returns true false
    }

    function place(uint32 gameID, uint8 x, string memory letter) internal{
        Game storage game = gameIDtoGame[gameID];
        require(game.nowPlaying == msg.sender, "It is not your turn");
        require(game.player2 != address(0), "Game not started yet. Wait for player2");
        require(x <= 9 && x >= 1, "The input must be from 1 to 9 (cells)");

        game.gameState = replaceGameState(game.gameState, x, letter);
        game.round++;
        game.lastMoveTime = block.timestamp;
        (bool finish, bool winner) = checkFinish(game);
        address _nowPlaying = game.nowPlaying;
        if (finish) {
            resetGame(game);
            if (winner) {
                _nowPlaying.call{value: (1.8 ether)}("");
                deposit += 0.2 ether;
            } else {
                deposit += 2 ether;
            }
        }else {
            game.nowPlaying = game.nowPlaying == game.player1 ? game.player2 : game.player1;
        }
        emit MoveEvent(_nowPlaying, x, bytes(letter)[0] == bytes('S')[0] ? 1 : 2);
    }

    function ur2slow() public {
        Game storage game = gameIDtoGame[playerToGameID[msg.sender]];
        require((msg.sender == game.player1) || (msg.sender == game.player2), "You are not currently playing");
        require(msg.sender != game.nowPlaying, "You cannot call ur2slow because it's your turn");
        require(game.round!=0, 'No one played yet');
        require(block.timestamp - 1 minutes > game.lastMoveTime, "1 minute not passed yet, be patient");
        resetGame(game);
        msg.sender.call{value: (1.9 ether)}(""); //returns true false
        emit MoveEvent(msg.sender, 0, 0);
        deposit += 0.1 ether;
    }

    // extra public function to allow resuming a game after reload
    function resume() public view returns(string memory, address, address)  {
        uint32 gameID = playerToGameID[msg.sender];
        if (gameID == 0) {
            return ("", address(0), address(0));
        }

        Game memory game = gameIDtoGame[gameID];
        address opponent = game.player1 == msg.sender ? game.player2 : game.player1;
        return (game.gameState, opponent, game.nowPlaying);
    }

    function checkFinish(Game memory game) internal view returns(bool, bool) {
        bytes memory stateBytes = bytes(game.gameState);

        for (uint8 i=0; i < winningTriplets.length; i++) {
            uint8[] memory triplet = winningTriplets[i];

            if (sosCheck(
                    stateBytes[triplet[0]],
                    stateBytes[triplet[1]],
                    stateBytes[triplet[2]]
                )) {
                return (true,true);
            }
        }
        return (game.round == 9,false);
    }

    function replaceGameState(string memory gameState, uint8 x, string memory letter) internal pure returns(string memory){
        bytes memory stateBytes = bytes(gameState);

        if (stateBytes[x-1] == bytes("-")[0]){ //attach another value only if it is blank
            stateBytes[x-1] = bytes(letter)[0]; //replace empty with letter
        } else {
            revert("You cannot play in this cell. It is filled"); // Player will not lose turn
        }

        return string(stateBytes);
    }

    function sosCheck(bytes1 first, bytes1 second, bytes1 third) internal pure returns(bool) {
        return first == "S" && second == "O" && third == "S";
    }

    function resetGame(Game storage game) internal{
        playerToGameID[game.player1] = 0;
        playerToGameID[game.player2] = 0;
        game.gameState = '';
        game.round = 0;
        game.player1 = address(0);
        game.player2 = address(0);
        game.nowPlaying = address(0);
        game.gameID = 0;
        game.lastMoveTime = 0;
        game.player1JoinTime = 0;
        game.isPending = false;
    }

}
