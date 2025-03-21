// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions


/*
The system is designed to have tokens maintain a 1 token = $1 peg
The stablecoin is based on exopgeneous collateral, dollar pegged, ad algorithmically stable
It's similar to a DAI system, but instead of a centralized authority, it's algorithmically stable due to the collateral

The contract is from the Patrick Collins "How to make a Stablecoin" Foundry tutorial 
and is loosely based on the MakerDAO DSS (DAI) system

This handles the main logic, including mining/redeeming DSC, and depositing/withdrawing collateral
The DSC system should always be overcollateralized.abi
At no point should the value of all collateral be less than the value of all the DSC
*/

pragma solidity 0.8.29;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract DSCEngine is ReentrancyGuard {
    
    //////////////////////
    // Errors           //
    //////////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();


    //////////////////////
    // State Variables  //
    //////////////////////

    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    DecentralizedStableCoin private immutable i_dsc;

    //////////////////////
    // Events           //
    //////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);


    //////////////////////
    // Modifiers        //
    //////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) revert DSCEngine__NeedsMoreThanZero();
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) revert DSCEngine__NotAllowedToken();
        _;
    }


    //////////////////////
    //  Functions       //
    //////////////////////

    constructor(
        address[] memory tokenAddresses, 
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();

        for (uint i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            i_dsc = DecentralizedStableCoin(dscAddress);
        }
    }

    /////////////////////////
    //  External Functions //
    /////////////////////////


    function depositCollateralAndMintDsc() external {}


    /* 
    * @param tokenCollateralAddress: The address of the token to deposit as collateral
    * @param amountCollateral: The amount of collateral to deposit
    * @notice Follows checks-effects-interactions pattern
    */
    function depositCollateral(
        address tokenCollateralAddress, 
        uint amountCollateral
    ) external 
    moreThanZero(amountCollateral) 
    isAllowedToken(tokenCollateralAddress) 
    nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) revert DSCEngine__TransferFailed();

    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {} 

    function liquidate() external {}

    function getHealthFactor() external view {}



}
