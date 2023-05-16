//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "../interfaces/INodeModule.sol";
import "../nodes/ReducerNode.sol";
import "../nodes/ExternalNode.sol";
import "../nodes/Api3Node.sol";
import "../nodes/PythNode.sol";
import "../nodes/ChainlinkNode.sol";
import "../nodes/PriceDeviationCircuitBreakerNode.sol";
import "../nodes/StalenessCircuitBreakerNode.sol";
import "../nodes/UniswapNode.sol";
import "../nodes/ConstantNode.sol";

import "../storage/NodeOutput.sol";
import "../storage/NodeDefinition.sol";

/**
 * @title Module for managing nodes
 * @dev See INodeModule.
 */
contract NodeModule is INodeModule {
    /**
     * @inheritdoc INodeModule
     */
    function registerNode(
        NodeDefinition.NodeType nodeType,
        bytes memory parameters,
        bytes32[] memory parents
    ) external returns (bytes32 nodeId) {
        NodeDefinition.Data memory nodeDefinition = NodeDefinition.Data({
            parents: parents,
            nodeType: nodeType,
            parameters: parameters
        });

        return _registerNode(nodeDefinition);
    }

    /**
     * @inheritdoc INodeModule
     */
    function getNodeId(
        NodeDefinition.NodeType nodeType,
        bytes memory parameters,
        bytes32[] memory parents
    ) external pure returns (bytes32 nodeId) {
        NodeDefinition.Data memory nodeDefinition = NodeDefinition.Data({
            parents: parents,
            nodeType: nodeType,
            parameters: parameters
        });

        return _getNodeId(nodeDefinition);
    }

    /**
     * @inheritdoc INodeModule
     */
    function getNode(bytes32 nodeId) external view returns (NodeDefinition.Data memory node) {
        return _getNode(nodeId);
    }

    /**
     * @inheritdoc INodeModule
     */
    function process(bytes32 nodeId) external view returns (NodeOutput.Data memory node) {
        return _process(nodeId);
    }

    /**
     * @dev Returns node definition data for a given node id.
     */
    function _getNode(bytes32 nodeId) internal view returns (NodeDefinition.Data storage node) {
        return NodeDefinition.load(nodeId);
    }

    /**
     * @dev Returns the ID of a node, whether or not it has been registered.
     */
    function _getNodeId(
        NodeDefinition.Data memory nodeDefinition
    ) internal pure returns (bytes32 nodeId) {
        return NodeDefinition.getId(nodeDefinition);
    }

    /**
     * @dev Returns the ID of a node after registering it
     */
    function _registerNode(
        NodeDefinition.Data memory nodeDefinition
    ) internal returns (bytes32 nodeId) {
        // If the node has already been registered with the system, return its ID.
        nodeId = _getNodeId(nodeDefinition);
        if (_isNodeRegistered(nodeId)) {
            // even though we do nothing else node is considered "re-registered" and returns as such
            emit NodeRegistered(
                nodeId,
                nodeDefinition.nodeType,
                nodeDefinition.parameters,
                nodeDefinition.parents
            );
            return nodeId;
        }

        // Validate that the node definition
        if (!_isValidNodeDefinition(nodeDefinition)) {
            revert InvalidNodeDefinition(nodeDefinition);
        }

        // Confirm that all of the parent node IDs have been registered.
        for (uint256 i = 0; i < nodeDefinition.parents.length; i++) {
            if (!_isNodeRegistered(nodeDefinition.parents[i])) {
                revert NodeNotRegistered(nodeDefinition.parents[i]);
            }
        }

        // Register the node
        (, nodeId) = NodeDefinition.create(nodeDefinition);
        emit NodeRegistered(
            nodeId,
            nodeDefinition.nodeType,
            nodeDefinition.parameters,
            nodeDefinition.parents
        );
    }

    /**
     * @dev Returns whether a given node ID has already been registered.
     */
    function _isNodeRegistered(bytes32 nodeId) internal view returns (bool nodeRegistered) {
        NodeDefinition.Data memory nodeDefinition = NodeDefinition.load(nodeId);
        return (nodeDefinition.nodeType != NodeDefinition.NodeType.NONE);
    }

    /**
     * @dev Returns the output of a specified node.
     */
    function _process(bytes32 nodeId) internal view returns (NodeOutput.Data memory price) {
        NodeDefinition.Data memory nodeDefinition = NodeDefinition.load(nodeId);

        if (nodeDefinition.nodeType == NodeDefinition.NodeType.REDUCER) {
            return
                ReducerNode.process(
                    _processParentNodeOutputs(nodeDefinition),
                    nodeDefinition.parameters
                );
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.EXTERNAL) {
            return
                ExternalNode.process(
                    _processParentNodeOutputs(nodeDefinition),
                    nodeDefinition.parameters
                );
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.CHAINLINK) {
            return ChainlinkNode.process(nodeDefinition.parameters);
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.UNISWAP) {
            return UniswapNode.process(nodeDefinition.parameters);
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.PYTH) {
            return PythNode.process(nodeDefinition.parameters);
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.API3) {
            return Api3Node.process(nodeDefinition.parameters);
        } else if (
            nodeDefinition.nodeType == NodeDefinition.NodeType.PRICE_DEVIATION_CIRCUIT_BREAKER
        ) {
            return
                PriceDeviationCircuitBreakerNode.process(
                    _processParentNodeOutputs(nodeDefinition),
                    nodeDefinition.parameters
                );
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.STALENESS_CIRCUIT_BREAKER) {
            return
                StalenessCircuitBreakerNode.process(
                    _processParentNodeOutputs(nodeDefinition),
                    nodeDefinition.parameters
                );
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.CONSTANT) {
            return ConstantNode.process(nodeDefinition.parameters);
        }
        revert UnprocessableNode(nodeId);
    }

    /**
     * @dev Returns the output of a specified node.
     */
    function _isValidNodeDefinition(
        NodeDefinition.Data memory nodeDefinition
    ) internal returns (bool valid) {
        if (
            nodeDefinition.nodeType == NodeDefinition.NodeType.REDUCER ||
            nodeDefinition.nodeType == NodeDefinition.NodeType.PRICE_DEVIATION_CIRCUIT_BREAKER ||
            nodeDefinition.nodeType == NodeDefinition.NodeType.STALENESS_CIRCUIT_BREAKER
        ) {
            //check if parents are processable
            _processParentNodeOutputs(nodeDefinition);
        }

        if (nodeDefinition.nodeType == NodeDefinition.NodeType.REDUCER) {
            return ReducerNode.isValid(nodeDefinition);
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.EXTERNAL) {
            return ExternalNode.isValid(nodeDefinition);
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.CHAINLINK) {
            return ChainlinkNode.isValid(nodeDefinition);
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.UNISWAP) {
            return UniswapNode.isValid(nodeDefinition);
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.PYTH) {
            return PythNode.isValid(nodeDefinition);
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.API3) {
            return Api3Node.isValid(nodeDefinition);
        } else if (
            nodeDefinition.nodeType == NodeDefinition.NodeType.PRICE_DEVIATION_CIRCUIT_BREAKER
        ) {
            return PriceDeviationCircuitBreakerNode.isValid(nodeDefinition);
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.STALENESS_CIRCUIT_BREAKER) {
            return StalenessCircuitBreakerNode.isValid(nodeDefinition);
        } else if (nodeDefinition.nodeType == NodeDefinition.NodeType.CONSTANT) {
            return ConstantNode.isValid(nodeDefinition);
        }
        return false;
    }

    /**
     * @dev helper function that calls process on parent nodes.
     */
    function _processParentNodeOutputs(
        NodeDefinition.Data memory nodeDefinition
    ) private view returns (NodeOutput.Data[] memory parentNodeOutputs) {
        parentNodeOutputs = new NodeOutput.Data[](nodeDefinition.parents.length);
        for (uint256 i = 0; i < nodeDefinition.parents.length; i++) {
            parentNodeOutputs[i] = this.process(nodeDefinition.parents[i]);
        }
    }
}
