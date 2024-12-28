// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {MultiSigWalletWithTimelock} from "./MultiSigWallet.sol";

contract ProxyFactory {
    using Clones for address;

    address public immutable logicImplementation;
    address[] public proxies;

    event ProxyCreated(address proxy);

    constructor(address _logicImplementation) {
        logicImplementation = _logicImplementation;
    }

    function createProxy() external returns (address proxy) {
        proxy = logicImplementation.clone();
        MultiSigWalletWithTimelock(payable(proxy)).initialize(); // Initialize the proxy
        proxies.push(proxy);
        emit ProxyCreated(proxy);
    }

    function getProxies() external view returns (address[] memory) {
        return proxies;
    }
}
