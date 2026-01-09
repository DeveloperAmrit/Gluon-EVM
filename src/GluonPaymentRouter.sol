// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IGluon {
    function fission(uint256 amountIn, address to, bytes[] calldata updateData) external payable;
    function NEUTRON_TOKEN() external view returns (address);
    function PROTON_TOKEN() external view returns (address);
}

/**
 * @title GluonPaymentRouter
 * @notice Helper contract to split Fission outputs:
 *         - Neutrons (Stable) -> Sent to Merchant
 *         - Protons (Volatile) -> Returned to User (Payer)
 */
contract GluonPaymentRouter {
    IGluon public gluon;
    IERC20 public neutron;
    IERC20 public proton;

    constructor(address _gluon) {
        gluon = IGluon(_gluon);
        neutron = IERC20(gluon.NEUTRON_TOKEN());
        proton = IERC20(gluon.PROTON_TOKEN());
    }

    /**
     * @notice Performs fission with the attached value, sends Neutrons to merchant, returns Protons to sender.
     * @param merchant The address of the merchant to receive the stable payment.
     * @param updateData Pyth oracle update data (if needed).
     */
    function payWithFission(address merchant, bytes[] calldata updateData) external payable {
        // 1. Perform Fission, minting both tokens to this contract
        gluon.fission{value: msg.value}(msg.value, address(this), updateData);

        // 2. Determine amounts minted
        uint256 nBal = neutron.balanceOf(address(this));
        uint256 pBal = proton.balanceOf(address(this));

        // 3. Forward Neutrons to Merchant
        if (nBal > 0) {
            neutron.transfer(merchant, nBal);
        }

        // 4. Return Protons to Payer (User)
        if (pBal > 0) {
            proton.transfer(msg.sender, pBal);
        }
    }
    
    // Allow contract to receive ETH if needed (though fission usually consumes it)
    receive() external payable {}
}
