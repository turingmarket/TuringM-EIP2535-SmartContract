// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {Facet} from "../../Facet.sol";
import {IPausableFacet} from "./IFacet.sol";
import {ROLE_OPERATOR_MANAGER} from "../../Constants.sol";
import {AccessControlBase} from "../AccessControl/Base.sol";

contract PausableFacet is IPausableFacet, AccessControlBase, Facet {
    function PausableFacet_init() external onlyInitializing {
        _setFunctionAccess(this.pause.selector, ROLE_OPERATOR_MANAGER, true);
        _setFunctionAccess(this.unpause.selector, ROLE_OPERATOR_MANAGER, true);
        _addInterface(type(IPausableFacet).interfaceId);
    }

    function pause() external protected {
        _pause();
    }

    function unpause() external protected {
        _unpause();
    }

    function paused() external view returns (bool) {
        return _paused();
    }
}
