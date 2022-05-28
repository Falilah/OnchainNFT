// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./lib/Base64.sol";

contract OnChainNFT is Ownable, ERC721("LeoGold", "LOGD") {
    struct ContractData {
        address rawContract;
        uint256 size;
        uint256 offset;
    }
    struct ContractDataPages {
        uint256 maxPageNumber;
        bool exists;
        mapping(uint256 => ContractData) pages;
    }
    mapping(string => ContractDataPages) internal _contractDataPages;

    function saveData(
        string memory _key,
        uint128 _pageNumber,
        bytes memory _b
    ) public {
        require(
            _b.length <= 24576,
            "SVGStorage: contract size exceeded 24576 max contract size limit"
        );
        ///cvreate the header for the contract data
        bytes memory init = hex"610000_600e_6000_39_610000_6000_f3";
        bytes1 size1 = bytes1(uint8(_b.length));
        bytes1 size2 = bytes1(uint8(_b.length >> 8));
        init[2] = size1;
        init[1] = size2;
        init[10] = size1;
        init[9] = size2;

        // Prepare the code for storage in a contract
        bytes memory code = abi.encodePacked(init, _b);

        // Create the contract
        address dataContract;
        assembly {
            dataContract := create(0, add(code, 32), mload(code))
            if eq(dataContract, 0) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        // Store the record of the contract
        saveDataForDeployedContract(
            _key,
            _pageNumber,
            dataContract,
            uint128(_b.length),
            0
        );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return genData();
    }

    bytes constant k =
        abi.encodePacked(
            '{"name": "LeoGold #',
            "0",
            '", "description": "That Girl", "image": "data:image/svg+xml;base64,'
        );

    function genData() public view returns (string memory metadata) {
        string memory json = Base64.encode(
            bytes(abi.encodePacked(k, Base64.encode(getData("Gold")), "}"))
        );

        metadata = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
    }

    function outtt() public view returns (string memory out__) {
        out__ = Base64.encode(getData("dan"));
    }

    function saveDataForDeployedContract(
        string memory _key,
        uint256 _pageNumber,
        address dataContract,
        uint128 _size,
        uint128 _offset
    ) internal {
        // Pull the current data for the contractData
        ContractDataPages storage _cdPages = _contractDataPages[_key];

        // Store the maximum page
        if (_cdPages.maxPageNumber < _pageNumber) {
            _cdPages.maxPageNumber = _pageNumber;
        }

        // Keep track of the existance of this key
        _cdPages.exists = true;

        // Add the page to the location needed
        _cdPages.pages[_pageNumber] = ContractData(
            dataContract,
            _size,
            _offset
        );
    }

    function revokeContractData(string memory _key) public onlyOwner {
        delete _contractDataPages[_key];
    }

    function getSizeOfPages(string memory _key) public view returns (uint256) {
        // For all data within the contract data pages, iterate over and compile them
        ContractDataPages storage _cdPages = _contractDataPages[_key];

        // Determine the total size
        uint256 totalSize;
        for (uint256 idx; idx <= _cdPages.maxPageNumber; idx++) {
            totalSize += _cdPages.pages[idx].size;
        }

        return totalSize;
    }

    function getData(string memory _key) public view returns (bytes memory) {
        // Get the total size
        uint256 totalSize = getSizeOfPages(_key);

        // Create a region large enough for all of the data
        bytes memory _totalData = new bytes(totalSize);

        // Retrieve the pages
        ContractDataPages storage _cdPages = _contractDataPages[_key];

        // For each page, pull and compile
        uint256 currentPointer = 32;
        for (uint256 idx; idx <= _cdPages.maxPageNumber; idx++) {
            ContractData storage dataPage = _cdPages.pages[idx];
            address dataContract = dataPage.rawContract;
            uint256 size = uint256(dataPage.size);
            uint256 offset = uint256(dataPage.offset);

            // Copy directly to total data
            assembly {
                extcodecopy(
                    dataContract,
                    add(_totalData, currentPointer),
                    offset,
                    size
                )
            }

            // Update the current pointer
            currentPointer += size;
        }

        return _totalData;
    }

    function getDataForAll(string[] memory _keys)
        public
        view
        returns (bytes memory)
    {
        // Get the total size of all of the keys
        uint256 totalSize;
        for (uint256 idx; idx < _keys.length; idx++) {
            totalSize += getSizeOfPages(_keys[idx]);
        }

        // Create a region large enough for all of the data
        bytes memory _totalData = new bytes(totalSize);

        // For each key, pull down all data
        uint256 currentPointer = 32;
        for (uint256 idx; idx < _keys.length; idx++) {
            // Retrieve the set of pages
            ContractDataPages storage _cdPages = _contractDataPages[_keys[idx]];

            // For each page, pull and compile
            for (
                uint256 innerIdx;
                innerIdx <= _cdPages.maxPageNumber;
                innerIdx++
            ) {
                ContractData storage dataPage = _cdPages.pages[innerIdx];
                //     assembly {
                //         extcodecopy(
                //             dataContract,
                //             add(_totalData, currentPointer),
                //             offset,
                //             size
                //         )
                //     }

                //     // Update the current pointer
                //     currentPointer += size;
                // }

                // return _totalData;
                address dataContract = dataPage.rawContract;
                uint256 size = uint256(dataPage.size);
                uint256 offset = uint256(dataPage.offset);

                // Copy directly to total data
                assembly {
                    extcodecopy(
                        dataContract,
                        add(_totalData, currentPointer),
                        offset,
                        size
                    )
                }

                // Update the current pointer
                currentPointer += size;
            }

            return _totalData;
        }
    }

    function hasKey(string memory _key) public view returns (bool) {
        return _contractDataPages[_key].exists;
    }
}
