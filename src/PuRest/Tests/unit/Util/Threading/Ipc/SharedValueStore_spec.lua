describe("PuRest.Tests.Util.Threading.Ipc.SharedValueStore", function()
    local SharedValueStore = require "PuRest.Util.Threading.Ipc.SharedValueStore"

    describe("behaviour", function()
        it("should be correct", function()
            local svsName = "svs"
            local session0 = {id=92839,username="ezra"}
            local session0key = "session0"
            
            -- TODO: add tests to cover setting inital data and attempting to do so from a child thread failing (not with error but just no data corruption)
            local svs = SharedValueStore(svsName, {isOwner = true})

            local setValue, setKey, setExistingKey = svs.setValue(session0key, session0)
            
            assert.are.equal(session0, setValue)
            assert.are.same(session0, setValue)
            assert.are.equal(session0key, setKey)
            assert.is_false(setExistingKey)
        
            local getValue, getKey, getKeyPresent = svs.getValueAndLock(session0key)
        
            assert.are.same(session0, getValue)
            assert.are.equal(session0key, getKey)
            assert.is_true(getKeyPresent)
        
            session0.id = session0.id + 2
            session0.extra_prop = "fefmnifnei"
        
            setValue, setKey, setExistingKey = svs.setValueAndUnlock(session0key, session0)
        
            assert.are.equal(session0, setValue)
            assert.are.same(session0, setValue)
            assert.are.equal(session0key, setKey)
            assert.is_true(setExistingKey)

            getValue, getKey, getKeyPresent = svs.getValue(session0key)
        
            assert.are.same(session0, getValue)
            assert.are.equal(session0key, getKey)
            assert.is_true(getKeyPresent)

            local svs_alt = SharedValueStore(svsName, {semaphoreId = svs.getId()})
        
            getValue, getKey, getKeyPresent = svs_alt.getValue(session0key)

            assert.are.same(session0, getValue)
            assert.are.equal(session0key, getKey)
            assert.is_true(getKeyPresent)

            getValue, getKey, getKeyPresent = svs_alt.getValueAndLock(session0key)
        
            session0.extra_prop = nil
        
            setValue, setKey, setExistingKey = svs_alt.setValueAndUnlock(session0key, session0)
        
            assert.are.equal(session0, setValue)
            assert.are.same(session0, setValue)
            assert.are.equal(session0key, setKey)
            assert.is_true(setExistingKey)
        
            getValue, getKey, getKeyPresent = svs.getValue(session0key)
        
            assert.are.same(session0, getValue)
            assert.are.equal(session0key, getKey)
            assert.is_true(getKeyPresent)
        
            assert.has.errors(svs_alt.destroy)
            
            svs.destroy()
        
            assert.has.errors(svs.getValue)

            assert.has.errors(svs_alt.getValue)
            assert.has.errors(svs_alt.getValue)
        end)
    end)
end)
