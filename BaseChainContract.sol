// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import { IERC20 } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol';

//bsc 0x9A91cB0Fc64704fA4D18131F3B9f2C0210d5ec27 // avax
//gas 30000000000000000

/**
 * @title CallContract
 * @notice Send a message from chain A to chain B and stores gmp message
 */
contract CallContract is AxelarExecutable { 
    string public message;
    string public sourceChain;
    string public sourceAddress;
    event widthrawMoney(uint256 balance, address receiver,uint256 _safeId);
    event moneyWidthrawn(uint256 balance, address receiver,uint256 _safeId, uint256 chainId);
    event signedTransaction(address a1, address a2,uint256 _safeId);
    event safeCreated(address a1, address a2,uint256 _safeId);
    event addFundsEvent(address a1,address a2,uint256 _safeId,uint256 _funds);

    event sendNotification(address a1, address a2,uint256 _safeId, uint256 amt);
    IAxelarGasService public immutable gasService;  

    IERC20 public token;
    event Executed(string _from, string _message);

    /**
     * 
     * @param _gateway address of axl gateway on deployed chain
     * @param _gasReceiver address of axl gas service on deployed chain
     */
    constructor(address _gateway, address _gasReceiver) AxelarExecutable(_gateway) {
        gasService = IAxelarGasService(_gasReceiver);
        token = IERC20(0x7603946e5342d024DD4D5807769C8D5e7E6C6C21);
    }

    struct addr {
        string name;
        address a1;
        address a2;
        bool sts1;
        bool sts2;
        uint256 balance;
        uint256[] timestamps;
    }

    mapping(uint256 => addr) public safeOwner;
    uint256 public safeId;

     function createSafe(string memory _safeName, address _secondSigner,
             string calldata destinationChain,
        string calldata destinationAddress
     )
        external payable
        returns (uint256)
    {
        safeId++;
        safeOwner[safeId].name = _safeName;
        safeOwner[safeId].a1 = msg.sender;
        safeOwner[safeId].a2 = _secondSigner;
        emit safeCreated(safeOwner[safeId].a1, safeOwner[safeId].a2, safeId);

        bytes memory payload = abi.encode(safeId,_secondSigner);
        require(msg.value > 0, 'Gas payment is required');
        gasService.payNativeGasForContractCall{ value: msg.value }(
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            msg.sender
        );
        gateway.callContract(destinationChain, destinationAddress, payload);

        return (safeId);
    }

//set approval for owner 1
    function SetApproval(uint256 _safeId) public {
        require(
            msg.sender == safeOwner[_safeId].a1 &&
                safeOwner[_safeId].sts1 == false,
            "You are not the owner of the safe"
        );
        safeOwner[_safeId].sts1 = true;
        emit signedTransaction(safeOwner[_safeId].a1,safeOwner[_safeId].a2,_safeId);
    }

    function returnOwner(uint256 _safeId) external view returns (address) {
        return (safeOwner[_safeId].a2);
    }

//send notification about widthraw request
    function widthrawrequest(uint256 _safeId, uint256 _amt) public {
        require(
            msg.sender == safeOwner[_safeId].a1,
            "You are not the owner of the safe"
        );
        require(
            _amt <= safeOwner[_safeId].balance,
            "The amount is greater than Safe Balance"
        );
        emit sendNotification(
            safeOwner[_safeId].a1,
            safeOwner[_safeId].a2,
            _safeId,
            _amt
        );
    }

    function _execute(
        string calldata _sourceChain,
        string calldata _sourceAddress,
        bytes calldata _payload
    ) internal override {
        uint256 safeId;
        bool status;
        (safeId,status) = abi.decode(_payload, (uint256,bool));
        safeOwner[safeId].sts2 = status;
    }

    function withdraw(
        uint256 _safeId,
        uint256 _amt,
        address payable _addr
    ) public {
        if (
            safeOwner[_safeId].sts1 == true && safeOwner[_safeId].sts2 == true
        ) {
            require(
                _amt <= safeOwner[_safeId].balance,
                "The amount is greater than Safe Balance"
            );
            
            token.transfer(_addr,_amt);
                emit widthrawMoney(_amt, _addr,_safeId); //eidthraw money on different chain
                safeOwner[_safeId].sts1 = false;
                safeOwner[_safeId].sts2 = false;
                safeOwner[_safeId].balance = safeOwner[_safeId].balance - _amt;
                safeOwner[_safeId].timestamps.push(block.timestamp);

        }
    }

    function addFunds(uint256 _safeId,uint256 amount)public{
        require(safeOwner[_safeId].a1 == msg.sender || safeOwner[_safeId].a2 == msg.sender  ,"You are not owner of this safe");
        safeOwner[safeId].balance += amount; 
        token.transferFrom(msg.sender,address(this),amount);
        emit addFundsEvent(safeOwner[_safeId].a1,safeOwner[_safeId].a2,_safeId,amount);
    }

}