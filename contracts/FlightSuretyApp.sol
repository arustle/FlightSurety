pragma solidity ^0.6.2;
// SPDX-License-Identifier: UNLICENSED

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";





/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
  using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

  /********************************************************************************************/
  /*                                       DATA VARIABLES                                     */
  /********************************************************************************************/


  address private contractOwner;          // Account used to deploy contract
  address payable private _contractAddress;          // Account used to deploy contract


  // Flight status codes
  uint8 private constant STATUS_CODE_UNKNOWN = 0;
  uint8 private constant STATUS_CODE_ON_TIME = 10;
  uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
  uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
  uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
  uint8 private constant STATUS_CODE_LATE_OTHER = 50;



  /********************************************************************************************/
  /*                                       FUNCTION MODIFIERS                                 */
  /********************************************************************************************/

  // Modifiers help avoid duplication of code. They are typically used to validate something
  // before a function is allowed to be executed.

  /**
  * @dev Modifier that requires the "operational" boolean variable to be "true"
  *      This is used on all state changing functions to pause the contract in
  *      the event there is an issue that needs to be fixed
  */
  modifier requireIsOperational()
  {
    // Modify to call data contract's status
    require(true, "Contract is currently not operational");
    _;
    // All modifiers require an "_" which indicates where the function body will be added
  }

  /**
  * @dev Modifier that requires the "ContractOwner" account to be the function caller
  */
  modifier requireContractOwner()
  {
    require(msg.sender == contractOwner, "Caller is not contract owner");
    _;
  }

  /********************************************************************************************/
  /*                                       CONSTRUCTOR                                        */
  /********************************************************************************************/

  /**
  * @dev Contract constructor
  *
  */
  constructor
  (
    address payable dataContract
  )
  public
  {

    contractOwner = address(msg.sender);
    _contractAddress = payable(address(this));
    _flightSuretyData = FlightSuretyData(dataContract);
    _flightSuretyData.registerAirline(contractOwner);
  }

  /********************************************************************************************/
  /*                                       UTILITY FUNCTIONS                                  */
  /********************************************************************************************/

  function isOperational()
  public
  view
  returns (bool)
  {
    return _flightSuretyData.isOperational();
    // TODO: Modify to call data contract's status
  }

  /********************************************************************************************/
  /*                                     SMART CONTRACT FUNCTIONS                             */
  /********************************************************************************************/


  /**
   * @dev Add an airline to the registration queue
   *
   */
  function registerAirline
  (
    address newAirline
  )
  external
  requireRegisteredAirline(msg.sender)
  requireAnte(msg.sender)
  returns (bool success, uint256 votes)
  {
    // verify that caller has not already called this function
    bool isDuplicate = false;
    for (uint i = 0; i < _multiCalls.length; i++) {
      if (_multiCalls[i] == msg.sender) {
        isDuplicate = true;
        break;
      }
    }
    require(!isDuplicate, "Caller has already called this function!");

    uint registeredVoterCount = _flightSuretyData.getAirlineCount().add(1);
    _multiCalls.push(msg.sender);
    uint voteCount = _multiCalls.length;

    if (registeredVoterCount >= _MIN_AIRLINE_COUNT) {
      uint reqConsensus = registeredVoterCount.div(2);
      require(voteCount >= reqConsensus, "Required consensus not met!");
    }


    _multiCalls = new address[](0);
    _flightSuretyData.registerAirline(newAirline);
    return (true, voteCount);
    //    return (success, 0);
  }


  /**
   * @dev Register a future flight for insuring.
   *
   */
  function registerFlight
  (
    address airline,
    string memory flight,
    uint256 updatedTimestamp
  )
  public
  {
    _flightSuretyData.registerFlight(msg.sender, airline, flight, updatedTimestamp);
  }

  /**
   * @dev Called after oracle has updated flight status
   *
   */
  function processFlightStatus
  (
    address airline,
    string memory flight,
    uint256 timestamp,
    uint8 statusCode
  )
  internal
  {
    require(statusCode == STATUS_CODE_LATE_AIRLINE, "Status does not warrant a credit.");
    _flightSuretyData.creditInsurees(airline, flight, timestamp);
  }


  // Generate a request for oracles to fetch flight information
  function fetchFlightStatus
  (
    address airline,
    string memory flight,
    uint256 timestamp
  )
  external
  requireRegisteredAirline(msg.sender)
  requireAnte(msg.sender)
  {
    uint8 index = getRandomIndex(msg.sender);

    // Generate a unique key for storing the request
    bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
    oracleResponses[key] = ResponseInfo({
    requester : msg.sender,
    isOpen : true
    });

    emit OracleRequest(index, airline, flight, timestamp);
  }










  // region ORACLE MANAGEMENT

  // Incremented to add pseudo-randomness at various points
  uint8 private nonce = 0;

  // Fee to be paid when registering oracle
  uint256 public constant REGISTRATION_FEE = 1 ether;

  // Number of oracles that must respond for valid status
  uint256 private constant MIN_RESPONSES = 3;


  struct Oracle {
    bool isRegistered;
    uint8[3] indexes;
  }

  // Track all registered oracles
  mapping(address => Oracle) private oracles;

  // Model for responses from oracles
  struct ResponseInfo {
    address requester;                              // Account that requested status
    bool isOpen;                                    // If open, oracle responses are accepted
    mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
    // This lets us group responses and identify
    // the response that majority of the oracles
  }

  // Track all oracle responses
  // Key = hash(index, flight, timestamp)
  mapping(bytes32 => ResponseInfo) private oracleResponses;

  // Event fired each time an oracle submits a response
  event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

  event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

  // Event fired when flight status request is submitted
  // Oracles track this and if they have a matching index
  // they fetch data and submit a response
  event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);

  event PaidPassenger(address passenger, uint credit);

  // Register an oracle with the contract
  function registerOracle
  (
  )
  external
  payable
  {
    // Require registration fee
    require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

    uint8[3] memory indexes = generateIndexes(msg.sender);

    _contractAddress.transfer(msg.value);

    oracles[msg.sender] = Oracle({
    isRegistered : true,
    indexes : indexes
    });
  }

  function getMyIndexes
  (
  )
  view
  external
  returns (uint8[3] memory)
  {
    require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

    return oracles[msg.sender].indexes;
  }




  // Called by oracle when a response is available to an outstanding request
  // For the response to be accepted, there must be a pending request that is open
  // and matches one of the three Indexes randomly assigned to the oracle at the
  // time of registration (i.e. uninvited oracles are not welcome)
  function submitOracleResponse
  (
    uint8 index,
    address airline,
    string memory flight,
    uint256 timestamp,
    uint8 statusCode
  )
  external
  {
    require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


    bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
    require(oracleResponses[key].isOpen, "Request is closed or invalid.");

    oracleResponses[key].responses[statusCode].push(msg.sender);

    // Information isn't considered verified until at least MIN_RESPONSES
    // oracles respond with the *** same *** information
    emit OracleReport(airline, flight, timestamp, statusCode);
    if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

      emit FlightStatusInfo(airline, flight, timestamp, statusCode);

      // Handle flight status as appropriate
      processFlightStatus(airline, flight, timestamp, statusCode);
    }
  }


  // Returns array of three non-duplicating integers from 0-9
  function generateIndexes
  (
    address account
  )
  internal
  returns (uint8[3] memory)
  {
    uint8[3] memory indexes;
    indexes[0] = getRandomIndex(account);

    indexes[1] = indexes[0];
    while (indexes[1] == indexes[0]) {
      indexes[1] = getRandomIndex(account);
    }

    indexes[2] = indexes[1];
    while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
      indexes[2] = getRandomIndex(account);
    }

    return indexes;
  }

  // Returns array of three non-duplicating integers from 0-9
  function getRandomIndex
  (
    address account
  )
  internal
  returns (uint8)
  {
    uint8 maxValue = 10;

    // Pseudo random number...the incrementing nonce adds variation
    uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

    if (nonce > 250) {
      nonce = 0;
      // Can only fetch blockhashes for last 256 blocks so we adapt
    }

    return random;
  }

  // endregion


  // ---------------------------------
  IFlightSuretyData private _flightSuretyData;
  uint8 private _MIN_AIRLINE_COUNT = 5;
  address[] private _multiCalls = new address[](0);

  modifier requireAnte (address airline) {
    if (airline != contractOwner) {
      require(_flightSuretyData.getAirlineFunds(airline) >= 10, "Airline needs at least 10 ether in funding!");
    }
    _;
  }
  modifier requireRegisteredAirline (address airline) {
    require(_flightSuretyData.isAirline(airline), "Airline is not registered!");
    _;
  }

  function fund(address airline) public payable {
    fundContract(msg.value);

    _flightSuretyData.fund(airline, msg.value);
  }

  function fundContract(uint value) public payable {
    _contractAddress.transfer(value);
  }

  function buy
  (
    address airline,
    string memory flightName,
    uint256 timestamp
  )
  public
  payable {
    require(msg.value <= 1 ether, "Insurance cost cannot be more than 1 ether");
    require(block.timestamp <= timestamp, "This flight has departed.  It can no longer be insured.");
    require(!_flightSuretyData.isPersonInsured(msg.sender, airline, flightName, timestamp), "Passenger has already bought insurance.");

    _flightSuretyData.buy(msg.sender, msg.value, airline, flightName, timestamp);

    fundContract(msg.value);
    _flightSuretyData.fund(airline, msg.value);
  }

  function pay
  (
    address airline,
    string memory flightName,
    uint256 timestamp
  )
  public
  payable {

    uint payout = _flightSuretyData.pay(msg.sender, airline, flightName, timestamp);

    fundContract(payout);
    emit PaidPassenger(msg.sender, payout);
  }

  /**
  * @dev Fallback function for funding smart contract.
  *
  */
  fallback()
  external
  payable
  {
    //    fund();
  }

  receive()
  external
  payable
  {
    //    _contractAddress.transfer(msg.value);
  }




  //  modifier requireConsensus () {
  //    uint newCount = _flightSuretyData.getAirlineCount().add(1);
  //
  //    if (newCount >= _MIN_AIRLINE_COUNT) {
  //      uint reqConsensus = newCount.div(2);
  //      require(_consensus.length >= reqConsensus, "Required consensus not met!");
  //    }
  //    _;
  //  }
}   
