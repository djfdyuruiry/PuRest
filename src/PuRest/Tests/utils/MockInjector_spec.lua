describe("MockInjector", function()
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

    describe("when require is called", function()
        it("should inject mocks", function()
            local util = require "some.util"

            util()

            assert.True(mockWasUsed)
        end)
    end)
end)
