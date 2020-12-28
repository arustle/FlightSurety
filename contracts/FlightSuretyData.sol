pragma solidity ^0.6.2;
// SPDX-License-Identifier: UNLICENSED

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


interface IFlightSuretyData {
  function isOperational() external view returns (bool);

  function registerAirline(address newAirline) external;

  function registerFlight(address msgSender, address airline, string memory flight, uint256 updatedTimestamp) external;

  function getAirlineCount() external view returns (uint);

  function setOperatingStatus(bool mode) external;

  function getAirlineFunds(address airline) external view returns (uint);

  function fund(address airline, uint msgValue) external payable;
  //  struct Airline {
  //    bool isRegistered;
  //    uint256 funds;
  //  }
  function isAirline(address airline) external view returns (bool);

  function pay(address payable insuredAddress, address airline, string memory flight, uint256 timestamp) external payable returns (uint);

  function buy(
    address payable passenger,
    uint price,
    address airline, string memory flight, uint256 timestamp) external payable;

  function creditInsurees(address airline, string memory flight, uint256 timestamp) external;

  function isPersonInsured(address passenger, address airline, string memory flightName, uint256 timestamp) external view returns (bool);


}

contract FlightSuretyData is IFlightSuretyData {
  using SafeMath for uint256;

  /********************************************************************************************/
  /*                                       DATA VARIABLES                                     */
  /********************************************************************************************/

  address private _contractOwner;                                      // Account used to deploy contract
  bool private operational = true;                                    // Blocks all state changes throughout the contract if false


  struct Airline {
    bool isRegistered;
    uint funds;
    string name;
  }

  struct InsuredPassenger {
    bool isInsured;
    uint insuredAmount;
    uint creditOwed;
    uint insuredAddressIndex;
  }

  struct Flight {
    bool isRegistered;
    uint8 statusCode;
    uint256 updatedTimestamp;
    address airline;
    address[] insuredAddresses;
    mapping(address => InsuredPassenger) insuredPassengers;
  }

  mapping(bytes32 => Flight) private _flights;
  /********************************************************************************************/
  /*                                       EVENT DEFINITIONS                                  */
  /********************************************************************************************/


  /**
  * @dev Constructor
  *      The deploying account becomes _contractOwner
  */
  constructor
  (
  //    address contractOwner
  )
  public
  {
    _contractOwner = msg.sender;
    _airlineCount = 0;
  }


  event AddedFunds();
  event RegisteredAirline();
  event IssuedCredit(address passenger, address airline, string flight, uint256 timestamp, uint credit);

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
    require(operational, "Contract is currently not operational");
    _;
    // All modifiers require an "_" which indicates where the function body will be added
  }

  /**
  * @dev Modifier that requires the "ContractOwner" account to be the function caller
  */
  modifier requireContractOwner()
  {
    require(msg.sender == _contractOwner, "Caller is not contract owner");
    _;
  }

  /********************************************************************************************/
  /*                                       UTILITY FUNCTIONS                                  */
  /********************************************************************************************/

  /**
  * @dev Get operating status of contract
  *
  * @return A bool that is the current operating status
  */
  function isOperational()
  external
  override
  view
  returns (bool)
  {
    return operational;
  }


  /**
  * @dev Sets contract operations on/off
  *
  * When operational mode is disabled, all write transactions except for this one will fail
  */
  function setOperatingStatus
  (
    bool mode
  )
  external
  override
  requireContractOwner
  {
    operational = mode;
  }

  /********************************************************************************************/
  /*                                     SMART CONTRACT FUNCTIONS                             */
  /********************************************************************************************/

  /**
   * @dev Add an airline to the registration queue
   *      Can only be called from FlightSuretyApp contract
   *
   */
  function registerAirline
  (
    address newAirline
  )
  external
  override
  {
    require(newAirline != address(0));
    require(!(_airlines[newAirline].isRegistered == true), "Airline is already registered!");


    _airlines[newAirline].isRegistered = true;
    _airlineCount++;
    emit RegisteredAirline();
  }

  function registerFlight
  (
    address msgSender,
    address airline,
    string memory flightName,
    uint256 updatedTimestamp
  )
  external
  override
  requireIsOperational
  {
    require(airline == msgSender, "You can only register flights for your airline!");
    bytes32 key = getFlightKey(airline, flightName, updatedTimestamp);

    require(_flights[key].updatedTimestamp != updatedTimestamp, "There are no changes to register.");


    Flight storage flight = _flights[key];


    flight.isRegistered = true;
    flight.updatedTimestamp = updatedTimestamp;
    flight.airline = airline;
    flight.insuredAddresses = new address[](0);

    //    _flights[key] = Flight({
    //    isRegistered : true,
    //    statusCode : STATUS_CODE_ON_TIME,
    //    updatedTimestamp : updatedTimestamp,
    //    airline : airline,
    //    insuredAddresses : addresses
    //    });

  }


  event BoughtInsurance(address passenger, uint price, address airline, string flightName, uint256 timestamp);
  /**
   * @dev Buy insurance for a flight
   *
   */
  function buy
  (
    address payable passenger,
    uint price,
    address airline,
    string memory flightName,
    uint256 timestamp
  )
  external
  requireIsOperational
  payable
  override
  {
    bytes32 flightKey = getFlightKey(airline, flightName, timestamp);

    Flight storage flight = _flights[flightKey];
    InsuredPassenger storage insuredPassenger = flight.insuredPassengers[passenger];

    if (insuredPassenger.isInsured == false) {
      insuredPassenger.insuredAddressIndex = flight.insuredAddresses.length;
      flight.insuredAddresses.push(passenger);
    }

    uint price1 = price;

    insuredPassenger.isInsured = true;
    insuredPassenger.insuredAmount = price1;
    insuredPassenger.creditOwed = 0;

    emit BoughtInsurance(passenger, price, airline, flightName, timestamp);

  }

  /**
   *  @dev Credits payouts to insurees
  */
  function creditInsurees
  (
    address airline,
    string memory flightName,
    uint256 timestamp
  )
  external
  requireIsOperational
  override
  {
    bytes32 flightKey = getFlightKey(airline, flightName, timestamp);
    Flight storage flight = _flights[flightKey];


    for (uint i = 0; i < flight.insuredAddresses.length; i++) {
      address insuredAddress = flight.insuredAddresses[i];
      InsuredPassenger memory insuredPassenger = flight.insuredPassengers[insuredAddress];

      if (insuredPassenger.insuredAmount > 0) {
        uint credit = insuredPassenger.insuredAmount.mul(15).div(10);

        flight.insuredPassengers[insuredAddress].creditOwed = credit;
        flight.insuredPassengers[insuredAddress].insuredAmount = 0;

        emit IssuedCredit(insuredAddress, airline, flightName, timestamp, credit);
      }
    }
  }


  /**
   *  @dev Transfers eligible payout funds to insuree
   *
  */
  function pay
  (
    address payable insuredAddress,
    address airline,
    string memory flightName,
    uint256 timestamp
  )
  external
  requireIsOperational
  payable
  override
  returns (uint)
  {

    bytes32 flightKey = getFlightKey(airline, flightName, timestamp);
    Flight storage flight = _flights[flightKey];
    InsuredPassenger memory insuredPassenger = flight.insuredPassengers[insuredAddress];
    uint payout = flight.insuredPassengers[insuredAddress].creditOwed;
    require(payout > 0, "There is no payout for this passenger.");
    require(_airlines[airline].funds >= payout, "The airline does not have enough funds to pay this request.");
    _airlines[airline].funds = _airlines[airline].funds.sub(payout);

    delete flight.insuredAddresses[insuredPassenger.insuredAddressIndex];
    delete flight.insuredPassengers[insuredAddress];

    return payout;
  }

  /**
   * @dev Initial funding for the insurance. Unless there are too many delayed flights
   *      resulting in insurance payouts, the contract should be self-sustaining
   *
   */
  function fund
  (
    address airline,
    uint msgValue
  )
  public
  requireIsOperational
  payable
  override
  {
    uint total = _airlines[airline].funds.add(msgValue);
    _airlines[airline].funds = total;
    emit AddedFunds();
  }

  function getFlightKey
  (
    address airline,
    string memory flightName,
    uint256 timestamp
  )
  pure
  internal
  returns (bytes32)
  {
    return keccak256(abi.encodePacked(airline, flightName, timestamp));
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
    fund(msg.sender, msg.value);
  }


  // -------------------------------------------------

  uint private _airlineCount;
  mapping(address => Airline) private _airlines;
  mapping(address => bool) private _authorizedAddresses;


  function authorizeCaller(address newAddress) public requireContractOwner {
    require(newAddress != address(0));
    require(!(_authorizedAddresses[newAddress] == true), "Address is already authorized!");
    _authorizedAddresses[newAddress] = true;
  }

  function isAirline(address airline) public view override returns (bool) {
    return _airlines[airline].isRegistered == true;
  }

  function getAirlineCount() external override view returns (uint) {
    return _airlineCount;
  }

  function getAirlineFunds(address airline) public view override returns (uint) {
    return _airlines[airline].funds;
  }

  function getAirlineName(address airline) public view returns (string memory) {
    return _airlines[airline].name;
  }

  function isFlightRegistered(address airline, string memory flightName, uint256 timestamp) public view returns (bool) {
    bytes32 flightKey = getFlightKey(airline, flightName, timestamp);
    Flight memory flight = _flights[flightKey];
    return flight.isRegistered;
  }

  function getInsuredAmount(address airline, string memory flightName, uint256 timestamp) public view returns (uint) {
    bytes32 flightKey = getFlightKey(airline, flightName, timestamp);
    InsuredPassenger memory insuredPassenger = _flights[flightKey].insuredPassengers[msg.sender];
    return insuredPassenger.insuredAmount;
  }

  function isPersonInsured(address passenger, address airline, string memory flightName, uint256 timestamp) external view override returns (bool) {
    bytes32 flightKey = getFlightKey(airline, flightName, timestamp);
    InsuredPassenger memory insuredPassenger = _flights[flightKey].insuredPassengers[passenger];
    return insuredPassenger.isInsured;
  }
  //  function getAirline(address airline) public view returns (Airline memory) {
  //    return _airlines[airline];
  //  }
}

