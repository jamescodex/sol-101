// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import "hardhat/console.sol";

// A smart contract that allows users to pay some funds in order to campaign their project on the platform
// The payment is dependent on the number of days they want to campaign on the platform
// Their project is then minted as an NFT and stored on the blockchain to be accessible by everyone

contract CampaignFactory is ERC721URIStorage, Ownable {
    struct Campaign {
        address owner;
        uint256 fundsIn;
        string name;
        uint256 startDate;
        uint256 endDate;
        uint256 dateCreated;
        bool claimedFunds;
    }

    using Counters for Counters.Counter;

    Counters.Counter private idCounter;
    uint256 private basePrice = 1 ether;

    mapping(uint256 => Campaign) private campaigns;

    constructor() ERC721("Campaign Factory", "CPF") {}

    /// @dev create new campaign
    function createCampaign(
        string memory _name,
        uint256 _startDate,
        uint256 _endDate,
        string memory _data
    ) public payable {
        require(strlen(_data) > 0, "Empty data");
        require(strlen(_name) > 0, "Empty name");
        require(
            !fundIsEnough(_startDate, _endDate),
            "Funds sent not enough for campaign"
        );

        uint256 tokenId = idCounter.current();
        idCounter.increment();
        string memory generatedURI = generateURI(_data, _name);
        console.log("Generated URI: ", generatedURI);

        // mint NFT representing campaign
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, generatedURI);
        campaigns[tokenId] = Campaign(
            msg.sender,
            0,
            _name,
            _startDate,
            _endDate,
            block.timestamp,
            false
        );
    }

    /// @dev get all campaigns
    function getAllCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory allCampaigns = new Campaign[](idCounter.current());
        for (uint256 i = 0; i < idCounter.current(); i++) {
            allCampaigns[i] = campaigns[i];
        }
        return allCampaigns;
    }

    /// @dev get a campaign
    function getSingleCampaign(uint256 _index)
        public
        view
        returns (Campaign memory)
    {
        return campaigns[_index];
    }

    /// @dev withdraw all funds sent to contract
    function withdrawFunds() public {
        require(msg.sender == owner(), "Unauthorised caller");
        uint256 total = address(this).balance;
        (bool sent, ) = payable(msg.sender).call{value: total}("");
        require(sent, "Failed to withdraw contract funds");
    }

    /// @dev check if funds send is enough to sponsor campaign
    function fundIsEnough(uint256 _startDate, uint256 _endDate)
        public
        payable
        returns (bool)
    {
        uint _days = 1 + (_endDate - _startDate) / 1 days;
        /*
      - _startDate and _endDate must be in the future
      - _days must be greater than 7 days
    */
        require(
            !(block.timestamp >= _startDate ||
                block.timestamp >= _endDate ||
                _days < 7),
            "Invalid dates entered"
        );
        uint256 total = calculatePrice(_endDate);
        return msg.value < total;
    }

    /// @dev calculate price of campaign
    function calculatePrice(uint256 _timeSpan) public view returns (uint256) {
        require(_timeSpan > block.timestamp);
        uint256 _days = 1 + (_timeSpan - block.timestamp) / 1 days;
        uint total = _days * basePrice;
        return total;
    }

    /**
     * @dev Returns the length of a given string
     *
     * @param s The string to measure the length of
     * @return The length of the input string
     */
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;
        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    // generate URI for token
    function generateURI(string memory _data, string memory _name)
        public
        pure
        returns (string memory)
    {
        string memory generated = string(
            abi.encodePacked("<svg>", _data, "</svg>")
        );
        uint256 length = strlen(_name);
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
        return string(abi.encodePacked("data:application/json;base64,", json));
    }
}
