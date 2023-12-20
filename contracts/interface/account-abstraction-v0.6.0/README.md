# Explanation

Due to the potential unexpected issues that 'foundry' may introduce in circular references (which could impact consumers relying on the 'SoulWalletCore' project), we have opted not to directly use 'git submodule' to depend on [account-abstraction v0.6.0](https://github.com/eth-infinitism/account-abstraction/tree/v0.6.0). Instead, we have copied some necessary files into the current directory.
