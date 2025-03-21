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
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
contract DSCEngine is ReentrancyGuard {
    
    //////////////////////
    // Errors           //
    //////////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);


    //////////////////////
    // State Variables  //
    //////////////////////

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DscMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    //////////////////////
    // Events           //
    //////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event DscMinted(address indexed user, uint256 indexed amountDscMinted);

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
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
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


    //check if collateral value > DSC amount (price feeds, values)
    /*
    * @param amountDscToMint: The amount of DSC to mint
    * @notice Collateral value should be greater than minimal threshold
    */
    function mintDsc(uint256 amountDscToMint) external 
    moreThanZero(amountDscToMint)
    nonReentrant
    {
        //get the amount of collateral
        s_DscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        emit DscMinted(msg.sender, amountDscToMint);
    }

    function burnDsc() external {} 

    function liquidate() external {}

    function getHealthFactor() external view {}


    ////////////////////////////////////////
    //  Private & Internal View Functions //
    ////////////////////////////////////////

    function _getAccountInformation(address user) private view returns (uint256 totalDscMinted, uint256 collateralValueInUsd) {
        totalDscMinted = s_DscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    //returns how close to liquidation a user is
    //if user < 1, liquidation is triggered
    function _healthFactor(address user) private view returns (uint256) {
        //total DSC minted
        //total collateral value
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        
        //e.g.) $1000 ETH / 100 DSC
        // 1000 * 50 / 100 = 500
        // 500 / 100 = 5 > 1, so not in danger
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }


    function _revertIfHealthFactorIsBroken(address user) internal view {
        if (_healthFactor(user) < MIN_HEALTH_FACTOR) revert DSCEngine__BreaksHealthFactor(userHealthFactor);
    }



    ////////////////////////////////////////
    //  Public & External View Functions //
    ////////////////////////////////////////

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        //loop through collateral tokens, get amount, and map to price to get USD value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        //returned value from chainlink will be 1000*1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION; 
    }


}
