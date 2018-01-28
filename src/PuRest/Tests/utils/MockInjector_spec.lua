describe("PuRest.Tests.utils.MockInjector", function()
    local MockInjector = require "PuRest.Tests.utils.MockInjector"
    local mockWasUsed = false

    setup(function()
        MockInjector.injectMocks({
            ["some.util"] = function()
                mockWasUsed = true
            end
        })
    end)

    teardown(function()
        MockInjector.clearMocks()
    end)

    describe("when injectMocks is called", function()
        describe("and then a package is required", function()
            it("should inject mocks", function()
                local util = require "some.util"

                util()

                assert.True(mockWasUsed)
            end)
        end)
    end)
end)
