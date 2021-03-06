const WeBuildWorldImplementation = artifacts.require("WeBuildWorldImplementation");
const WeBuildWorld = artifacts.require("WeBuildWorld");
const Promise = require("bluebird");

contract('WeBuildWord', function (accounts) {

  let main;
  let implement;
  let owner = accounts[0];
  let builder = accounts[1];

  before("Contracts should be able to deploy.", async () => {
    return await Promise.all([
      WeBuildWorldImplementation.deployed(),
      WeBuildWorld.deployed(),
    ]).spread(async (weBuildWorldImplementation, weBuildWorld) => {
      assert.ok(weBuildWorldImplementation, "WeBuildWorldImplementation contract is not deployed.");
      assert.ok(weBuildWorld, "WeBuildWorld contract is not deployed.");

      await weBuildWorldImplementation.setMain(weBuildWorld.address);
      await weBuildWorld.upgradeProvider(weBuildWorldImplementation.address);

      main = weBuildWorld;
      implement = weBuildWorldImplementation;

    });
  });


  it("test filter by owner and builder.", async () => {

    const txObj = await main.addBrick('brick1 title',
      'https://github.com/hello/mock/issue/100',
      new Date().getTime() / 1000,
      'mock1 brick description',
      ['mock', 'test'], {
        value: web3.toWei(1, "ether"),
        from: owner
      });

    const txObj2 = await main.addBrick('brick2 title',
      'https://github.com/hello/mock/issue/101',
      new Date().getTime() / 1000,
      'mock2 brick description',
      ['mock', 'test'], {
        value: web3.toWei(3, "ether"),
        from: builder
      });

    assert.ok(txObj, "success add brick.");
    assert.ok(txObj2, "success add brick.");

    const idsRes1 = await main.getBrickIdsByOwner(owner);
    console.log('ids:', idsRes1);

    const idsRes2 = await main.getBrickIdsByBuilder(builder);
    console.log('ids2:', idsRes2);
  

  });

  it("should be success added a brick.", async () => {

    const txObj = await main.addBrick('brick title',
      'https://github.com/hello/mock/issue/100',
      new Date().getTime() / 1000,
      'mock brick description',
      ['mock', 'test'], {
        value: web3.toWei(1, "ether"),
        from: owner
      });
    assert.ok(txObj, "success add brick.");

    const ids = (await main.getBrickIds(0, 10, ['mock', 'test'], -1, 0, 0) || [])
      .map((id) => id.toNumber())
      .filter(id => id !== 0);

    const brickId = ids[0];
    const brick = await main.getBrick(brickId);
    // console.log('brick:', brick);
    assert.ok(brick, "An brick can be found.");
    // assert.equal(ids.length, 1, 'An brick can be found.');
  });

});