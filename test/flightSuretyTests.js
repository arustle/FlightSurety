const Test = require('../config/testConfig.js');
const BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false, {from: config.testAddresses[2]});
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false);
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

    await config.flightSuretyData.setOperatingStatus(false);

    let reverted = false;
    try {
      await config.flightSurety.setTestingMode(true);
    } catch (e) {
      reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");

    // Set it back for other tests to work
    await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

    // ARRANGE
    let airline1 = accounts[2];
    let airline2 = accounts[3];

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(airline1, {from: config.owner});
      await config.flightSuretyApp.registerAirline(airline2, {from: airline1});
    } catch (e) {

    }
    let result = await config.flightSuretyData.isAirline.call(airline2);

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) can be funded', async () => {
    // ARRANGE
    let newAirline = accounts[4];

    // ACT
    try {
      await config.flightSuretyApp.fund.sendTransaction(newAirline, {
        from: newAirline,
        value: '9'
      });
    } catch (e) {
      assert.fail(e);
    }
    const bnFunds = await config.flightSuretyData.getAirlineFunds.call(newAirline);
    const funds = bnFunds.toString();

    // ASSERT
    assert.equal(funds, '9', "Airline should have 10 ether");
  });


  it('(airline) can register an Airline using registerAirline() if it has at least 10 eth funded', async () => {

    // ARRANGE
    let airline1 = accounts[3];
    let airline2 = accounts[4];

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(airline1, {from: config.owner});

      await config.flightSuretyApp.fund.sendTransaction(airline1, {
        from: airline1,
        value: '10',
      });
      await config.flightSuretyApp.registerAirline(airline2, {from: airline1});
    } catch (e) {
      assert.fail(e);
    }
    const isAirline = await config.flightSuretyData.isAirline.call(airline2);
    const bnFunds = await config.flightSuretyData.getAirlineFunds.call(airline1);
    const funds = bnFunds.toString();

    // ASSERT
    assert.equal(funds, '10', "Airline should have 10 ether");
    assert.equal(isAirline, true, "Airline should be able to register another airline if it has at least 10 eth funding");

  });


  it('(airline) can register a flight', async () => {

    // ARRANGE
    let airline1 = accounts[3];

    const flightTime = Math.floor((new Date()).getTime() / 1000);
    const flightName = 'Flight 1234';

    // ACT
    try {
      await config.flightSuretyApp.registerFlight(airline1, flightName, flightTime, {from: airline1});
    } catch (e) {
      assert.fail(e);
    }
    const isRegistered = await config.flightSuretyData.isFlightRegistered.call(airline1, flightName, flightTime);

    // ASSERT
    assert.equal(isRegistered, true, "Airline should be able to register flight");

  });


  it('(passenger) can buy insurance', async () => {

    // ARRANGE
    let airline1 = accounts[3];
    let passenger = config.testAddresses[0];

    const flightTime = Math.floor(((new Date()).getTime() + 1000 * 60 * 60) / 1000);
    const flightName = 'Flight 1234';
    const price = (0.13 * config.weiMultiple).toString();

    // ACT
    try {
      await config.flightSuretyApp.buy(airline1, flightName, flightTime, {from: passenger, value: price});
    } catch (e) {
      assert.fail(e);
    }
    const insuredAmount = await config.flightSuretyData.getInsuredAmount.call(airline1, flightName, flightTime, {from: passenger});

    // ASSERT
    assert.equal(insuredAmount.toString(), price, "Passenger insurance price should match insured amount");

  });

  it('(passenger) cannot pay more than 1 eth for insurance', async () => {

    // ARRANGE
    let airline1 = accounts[3];
    let passenger = config.testAddresses[1];

    const flightTime = Math.floor(((new Date()).getTime() + 1000 * 60 * 60) / 1000);
    const flightName = 'Flight 1234';
    const price = (1.4 * config.weiMultiple).toString();

    // ACT
    try {
      await config.flightSuretyApp.buy(airline1, flightName, flightTime, {from: passenger, value: price});
    } catch (e) {
      if (e.reason === 'Insurance cost cannot be more than 1 ether') {
        assert.equal(e.reason, 'Insurance cost cannot be more than 1 ether', "Insurance cost cannot be more than 1 ether");
      } else {
        assert.fail(e);
      }

    }
    const insuredAmount = await config.flightSuretyData.getInsuredAmount.call(airline1, flightName, flightTime, {from: passenger});

    // ASSERT
    assert.equal(insuredAmount.toString(), "0", "Passenger insurance price should be zero");

  });


  it('(passenger) is issued credit', async () => {

    // ARRANGE
    let airline1 = accounts[3];
    let passenger = config.testAddresses[1];

    const flightTime = Math.floor(((new Date()).getTime() + 1000 * 60 * 60) / 1000);
    const flightName = 'Flight 1234';
    const price = (0.4 * config.weiMultiple).toString();

    let insuredAmount;
    // ACT
    try {
      await config.flightSuretyApp.buy(airline1, flightName, flightTime, {from: passenger, value: price});
      insuredAmount = await config.flightSuretyData.getInsuredAmount.call(airline1, flightName, flightTime, {from: passenger});
      assert.equal(insuredAmount.toString(), price, "Passenger insurance price should match");

      await config.flightSuretyData.creditInsurees(airline1, flightName, flightTime);
      // await config.flightSuretyApp.processFlightStatus(airline1, flightName, flightTime, 20);
    } catch (e) {
      console.log(e)
    }
    insuredAmount = await config.flightSuretyData.getInsuredAmount.call(airline1, flightName, flightTime, {from: passenger});

    // ASSERT
    assert.equal(insuredAmount.toString(), "0", "Passenger insurance price should be zero");

  });

  it('(oracle) can access registration fee amount', async () => {

    // ARRANGE
    let passenger = config.testAddresses[1];


    // ACT
    const fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    // ASSERT
    assert.equal(fee.toString(), (1 * config.weiMultiple).toString(), "Registration fee should be 1 ETH");

  });
});
