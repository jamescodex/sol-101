// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { StringUtils } from "./library/StringUtils.sol";
import { Base64 } from "./library/Base64.sol";
import "hardhat/console.sol";

// A smart contract that allows users to pay some funds in order to campaign their project on the platform
// The payment is dependent on the number of days they want to campaign on the platform
// Their project is then minted as an NFT and stored on the blockchain to be accessible by everyone

contract CampaignFactory is ERC721URIStorage, Ownable {

  struct Campaign {
    uint256 id;    
    uint256 fundsIn;
    string name;
    uint256 startDate;
    uint256 endDate;    
    uint256 dateCreated;
    bool claimedFunds;
  }

  using Counters for Counters.Counter;
  
  Counters.Counter private idCounter;
  uint256 public totalCampaign;
  uint256 private basePrice = 1 ether;  

  mapping (uint256 => Campaign) internal campaigns;
  mapping (uint256 => address) internal ownerOfCampaign;

  constructor() ERC721("Campaign Factory", "CPF") {}

  // create new campaign
  function createCampaign(
    string memory _name,
    uint256 _startDate,
    uint256 _endDate,    
    string memory _data
  ) public payable {    
    require(!fundIsEnough(_startDate, _endDate), 
    "Funds sent not enough for campaign"
    );
    
    uint256 tokenId = idCounter.current();
    idCounter.increment;
    string memory generatedURI = generateURI(_data, _name);
    console.log("Generated URI: ", generatedURI);

    // mint NFT representing campaign
    _safeMint(msg.sender, tokenId);
    _setTokenURI(tokenId, generatedURI);
    idCounter.increment;    
    ownerOfCampaign[totalCampaign] = msg.sender;
    campaigns[totalCampaign++] = Campaign(
      totalCampaign,      
      0,
      _name,
      _startDate,
      _endDate,
      block.timestamp,
      false
    );
  }

  // get all campaigns
  function getAllCampaigns() public view returns (Campaign[] memory) {
    Campaign[] memory allCampaigns = new Campaign[](totalCampaign);
    for (uint256 i = 0; i < totalCampaign; i++) {
      allCampaigns[i] = campaigns[i];
    }
    return allCampaigns;
  }

  // get a campaign
  function getSingleCampaign(uint256 _index) public view returns (Campaign memory) {
    return campaigns[_index];
  }

  // withdraw all funds sent to contract
  function withdrawFunds() public {
    require(msg.sender == owner(), "Unauthorised");
    uint256 total = address(this).balance;
    (bool sent, ) = payable(msg.sender).call{value: total}("");
    require(sent, "Failed to withdraw contract funds");
  }

  // check if funds send is enough to sponsor campaign
  function fundIsEnough(uint256 _startDate, uint256 _endDate) public payable returns (bool) {    
    uint _days = 1 + (_endDate - _startDate) / 1 days;  
    /*
      - _startDate and _endDate must be in the future
      - _days must be greater than 7 days
    */
    require(!(block.timestamp >= _startDate || block.timestamp >= _endDate || _days < 7), "Invalid dates entered");  
    uint256 total = calculatePrice(_endDate);    
    return msg.value < total;
  }

  // calculate price of campaign
  function calculatePrice(uint256 _timeSpan) public view returns (uint256) {
    uint256 _days = 1 + (_timeSpan - block.timestamp) / 1 days;
    uint total = _days * basePrice;
    return total;  
  }

  // generate URI for token
  function generateURI(string memory _data, string memory _name) public pure returns (string memory) {
        string memory generated = string(abi.encodePacked("<svg>", _data, "</svg>"));
  	uint256 length = StringUtils.strlen(_name);
		string memory len = Strings.toString(length);
    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "',
            _name,
            '", "description": "NFT generated from Contract Factory", "image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(generated)),
            '","length":"',
            len,
            '"}'
          )
        )
      )
    );
    return string( abi.encodePacked("data:application/json;base64,", json));
  }

}
