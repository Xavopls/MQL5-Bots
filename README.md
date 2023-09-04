# MQL5-Bots

This is a collection of bots, indicators and scripts in order to test and to get familiarized with the MQL5 language and MT5 usage.    
It creates an isolated environment including all the resources inside the repository folder, therefore not following the MT5 default folder structure.    

## Install (Windows)

Clone into the `Experts` folder:     

`C:\Users\{USER}\AppData\Roaming\MetaQuotes\Terminal\{CODE}\MQL5\Experts`    

If you want to commit or push from the given path, it is likely that an additional command will be required:    

`git config --global --add safe.directory C:\Users\{USER}\AppData\Roaming\MetaQuotes\Terminal\{CODE}\MQL5\Experts\MQL5-Bots`    


## Utils

### Backtest

#### Backtest results
After every backtest, a .csv with the details of the trades will be stored in this path:

`C:\Users\{USER}\AppData\Roaming\MetaQuotes\Tester\{CODE}\Agent-127.0.0.1-3000\MQL5\Files`    

The filename is not relevant, sort it by date to get the latest.