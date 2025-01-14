// SPDX-License-Identifier: MIT

/*
 * Material Icon NFT (ERC721). The mint function takes IAssetStore.AssetInfo as a parameter.
 * It registers the specified asset to the AssetStore and mint a token which represents
 * the "uplaoder" of the asset (who paid the gas fee). After that, the asset will beome
 * available to other smart contracts either as CC0 or CC-BY (see the AssetStore for details).
 * 
 * Created by Satoshi Nakajima (@snakajima)
 */

pragma solidity ^0.8.6;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { IAssetStoreRegistry, IAssetStore } from './interfaces/IAssetStore.sol';
import { Base64 } from 'base64-sol/base64.sol';
import "@openzeppelin/contracts/utils/Strings.sol";

contract MaterialToken is Ownable, ERC721Enumerable {
  using Strings for uint256;
  using Strings for uint16;

  IAssetStoreRegistry public immutable registry;
  IAssetStore public immutable assetStore;

  mapping(uint256 => uint256) assetIds; // tokenId => assetId
  mapping(uint256 => bool) primaries;

  // description
  string public description = "This is one of effts to create (On-Chain Asset Store)[https://assetstore.xyz].";

  // The internal token ID tracker
  uint256 private _currentTokenId;

  constructor(IAssetStoreRegistry _registry, IAssetStore _assetStore) ERC721("Material Icons", "MATERIAL") {
    registry = _registry;
    assetStore = _assetStore;
  }

  function _safeMintWithAssetId(address _target, uint256 _assetId, bool _primary) internal returns(uint256) {
    uint256 tokenId = _currentTokenId++;
    _mint(_target, tokenId);
    assetIds[tokenId] = _assetId;
    primaries[tokenId] = _primary;
    return tokenId;    
  }

  function mint(IAssetStoreRegistry.AssetInfo memory _assetInfo, uint256 _affiliate) external returns(uint256) {
    uint256 assetId = registry.registerAsset(_assetInfo);
    uint256 tokenId = _safeMintWithAssetId(msg.sender, assetId, true);
    _safeMintWithAssetId(msg.sender, assetId, false);

    if (_affiliate > 0 && _exists(_affiliate)) {
      address affiliater = ownerOf(_affiliate); 
      if (affiliater != msg.sender) {
        _safeMintWithAssetId(ownerOf(_affiliate), assetId, false);
      }
    }
    return tokenId;    
  }

  function getAssetId(uint256 _tokenId) external view returns(uint256) {
    require(_exists(_tokenId), 'MaterialToken.getAssetId: nonexistent token');
    return assetIds[_tokenId];
  }

  function _generateClipPath(IAssetStore.AssetAttributes memory attr) internal pure returns (bytes memory) {
    string memory hw = (attr.width / 2).toString();
    string memory hh = (attr.height / 2).toString();
    return abi.encodePacked(
        abi.encodePacked(
        ' <clipPath id="nw"><rect x="0" y="0" width="', hw, '" height="', hh, '" /></clipPath>\n',
        ' <clipPath id="sw"><rect x="0" y="', hh, '" width="', hw, '" height="', hh, '" /></clipPath>\n'
        ), abi.encodePacked(
        ' <clipPath id="ne"><rect x="', hw, '" y="0" width="', hw, '" height="', hh, '" /></clipPath>\n',
        ' <clipPath id="se"><rect x="', hw, '" y="', hh, '" width="', hw, '" height="', hh, '" /></clipPath>\n'
        )
      );
  }
  /**
    * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    * @dev See {IERC721Metadata-tokenURI}.
    */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), 'MaterialToken.tokenURI: nonexistent token');
    uint256 assetId = assetIds[tokenId];
    IAssetStore.AssetAttributes memory attr = assetStore.getAttributes(assetId);
    string memory name = string(abi.encodePacked(attr.name));
    bytes memory assetTag = abi.encodePacked('#asset', assetId.toString());
    bytes memory image = abi.encodePacked(
      '<svg viewBox="0 0 ', attr.width.toString() ,' ', attr.height.toString(), '"  xmlns="http://www.w3.org/2000/svg">\n',
      '<defs>\n',
      ' <filter id="f1" x="0" y="0" width="200%" height="200%">\n',
      '  <feOffset result="offOut" in="SourceAlpha" dx="0.6" dy="1.0" />\n',
      '  <feGaussianBlur result="blurOut" in="offOut" stdDeviation="0.4" />\n',
      '  <feBlend in="SourceGraphic" in2="blurOut" mode="normal" />\n',
      ' </filter>\n',
      _generateClipPath(attr),
      assetStore.generateSVGPart(assetId),
      '</defs>\n');
    if (primaries[tokenId]) {
      image = abi.encodePacked(image,
        '<g filter="url(#f1)">\n',
        ' <use href="', assetTag ,'" fill="#4285F4" clip-path="url(#ne)" />',
        ' <use href="', assetTag ,'" fill="#34A853" clip-path="url(#se)" />',
        ' <use href="', assetTag ,'" fill="#FBBC05" clip-path="url(#sw)" />',
        ' <use href="', assetTag ,'" fill="#EA4335" clip-path="url(#nw)" />');
    } else {
      image = abi.encodePacked(image,
        '<g filter="url(#f1)" transform="scale(0.5)">\n');
      string[4] memory colors = ["#4285F4", "#34A853", "#FBBC05", "#EA4335"]; 
      uint16 i;
      for (i=0; i<4; i++) {
        uint16 x = (i % 2) * 24;
        uint16 y = (i / 2 % 2) * 24;
        image = abi.encodePacked(image,
          ' <use href="', assetTag ,'" fill="', colors[(i + tokenId) % 4], 
              '" x="', x.toString(), '" y="', y.toString(), '"/> \n');
      }
    }
    image = abi.encodePacked(image,'</g>\n</svg>');

    return string(
      abi.encodePacked(
        'data:application/json;base64,',
        Base64.encode(
          bytes(
            abi.encodePacked('{"name":"', name, '","description":"', description, 
               '","image":"', 'data:image/svg+xml;base64,', 
              Base64.encode(image), 
              '"}')
          )
        )
      )
    );
  }  
}