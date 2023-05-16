import assertBn from '@synthetixio/core-utils/utils/assertions/assert-bignumber';
import { ethers } from 'ethers';

import { bootstrap } from '../bootstrap';
import NodeTypes from '../mixins/Node.types';

const parseUnits = ethers.utils.parseUnits;

describe('Api3Node', function () {
  const { getContract, getSigners } = bootstrap();

  const abi = ethers.utils.defaultAbiCoder;
  let NodeModule: ethers.Contract;
  let MockIProxy: ethers.Contract;

  const decimals = 18;
  const price = parseUnits('2000', decimals).toString();

  before('prepare environment', async () => {
    NodeModule = getContract('NodeModule');

    const [owner] = getSigners();

    // Deploy the mock
    const factory = await hre.ethers.getContractFactory('MockIProxy');
    MockIProxy = await factory.connect(owner).deploy(price);
  });

  it('retrieves the latest price', async () => {
    const currentBlock = await hre.ethers.provider.getBlockNumber();
    const blockTimestamp = (await hre.ethers.provider.getBlock(currentBlock)).timestamp;
    // Register the mock
    const NodeParameters = abi.encode(['address'], [MockIProxy.address]);
    await NodeModule.registerNode(NodeTypes.API3, NodeParameters, []);
    const nodeId = await NodeModule.getNodeId(NodeTypes.API3, NodeParameters, []);

    // Verify the node processes output as expected
    const output = await NodeModule.process(nodeId);
    assertBn.equal(output.price, parseUnits(price, 18 - decimals).toString());
    assertBn.equal(output.timestamp, blockTimestamp);
  });
});
