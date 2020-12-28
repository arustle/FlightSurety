import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
  constructor(network, callback) {

    let config = Config[network];
    this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
    this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress, config.dataAddress);
    this.initialize(callback);
    this.owner = null;
    this.airlines = [];
    this.passengers = [];

    // ---
    this.flights = [];
  }

  initialize(callback) {
    this.web3.eth.getAccounts(async (error, accts) => {

      this.owner = accts[0];

      let counter = 1;

      while (this.airlines.length < 5) {
        this.airlines.push(accts[counter++]);
      }

      while (this.passengers.length < 5) {
        this.passengers.push(accts[counter++]);
      }


      callback();
    });
  }

  isOperational(callback) {
    let self = this;
    self.flightSuretyApp.methods
      .isOperational()
      .call({from: self.owner}, callback);
  }

  fetchFlightStatus(flightId, callback) {
    let self = this;
    const flight = this.flights.find(x => x.id === flightId);

    const payload = {
      airline: flight.airline,
      flight: flight.flight,
      timestamp: Math.floor(flight.timestamp / 1000)
    }
    self.flightSuretyApp.methods
      .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
      .send({
        from: self.owner
      }, (error, result) => {
        callback(error, result, payload);
      });
  }


  buyInsurance(flightId, priceEther, callback) {
    let self = this;

    const flight = this.flights.find(x => x.id === flightId);
    const priceWei = this.web3.utils.toWei(priceEther);

    const payload = {
      airline: flight.airline,
      flight: flight.flight,
      timestamp: Math.floor(flight.timestamp / 1000)
    }
    self.flightSuretyApp.methods
      .buy(payload.airline, payload.flight, payload.timestamp)
      .send({
        from: self.passengers[0],
        value: priceWei,
        gas: 4712388,
        gasPrice: 100000000000
      }, (error, result) => {
        callback(error, result);
      });
  }

  withdraw(flightId, callback) {
    let self = this;

    const flight = this.flights.find(x => x.id === flightId);

    const payload = {
      airline: flight.airline,
      flight: flight.flight,
      timestamp: Math.floor(flight.timestamp / 1000)
    }
    self.flightSuretyApp.methods
      .pay(payload.airline, payload.flight, payload.timestamp)
      .send({
        from: self.passengers[0],
        gas: 4712388,
        gasPrice: 100000000000
      }, (error, result) => {
        callback(error, result);
      });
  }
}