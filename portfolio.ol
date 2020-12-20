from file import File
from math import Math

type Quote {
  stock: string
  value: double
  initialValue: double
  gainValue: double
  gainPercent: double
}

type PortfolioType {
  gainValue: double
  gainPercent: double
  currentTotal: double
  initialTotal: double
  stocks[0,*]: Quote
}

type QuoteResponse { portfolio: PortfolioType }

// Define the API that we are going to publish
interface PortfolioAPI {
    RequestResponse: portfolio( void )( QuoteResponse )
}

service Portfolio {
    execution: concurrent 

    inputPort PortfolioInput {
        location: "socket://localhost:8181"
        protocol: http { format = "json" }
        interfaces: PortfolioAPI
    }

    outputPort YahooFinance {
      Location: "socket://query1.finance.yahoo.com:443/v7/finance/quote"
      Protocol: https {
        osc.getQuote.alias = "?symbols=%{q}"
        osc.getQuote.method = "get"
      }
      RequestResponse: getQuote 
    }    

	embed Math as Math
	embed File as File

    main {
        portfolio()( response ) {
            // read configuration
          	readFile@File( {
              filename = "portfolio.json"
              format = "json"
            } )( myPortfolio )
            // loop configured items
            for( index = 0, index < #myPortfolio.portfolio, index++ ) {
              // for each stock call Yahoo Finance API to get quote
              getQuote@YahooFinance( { q = myPortfolio.portfolio[index].stock } )( myQuote );         
              // and set output      
              response.portfolio.stocks[index].stock = myQuote.quoteResponse.result[0].shortName
              currValue = myPortfolio.portfolio[index].quantity * myQuote.quoteResponse.result[0].regularMarketPrice
              initialValue = myPortfolio.portfolio[index].quantity * myPortfolio.portfolio[index].initialPrice
              response.portfolio.stocks[index].value = currValue
              response.portfolio.stocks[index].initialValue = initialValue
              response.portfolio.stocks[index].gainValue = currValue - initialValue
              round@Math( (response.portfolio.stocks[index].gainValue / initialValue * 100) { decimals = 2 } )
                (response.portfolio.stocks[index].gainPercent)
              response.portfolio.currentTotal += currValue
              response.portfolio.initialTotal += initialValue
            }
            round@Math( (response.portfolio.currentTotal - response.portfolio.initialTotal) { decimals = 2 })
              (response.portfolio.gainValue)
            round@Math( (response.portfolio.gainValue / response.portfolio.initialTotal * 100) { decimals = 2 } )
              (response.portfolio.gainPercent)            
        }
    }
}