describe("PuRest.Util.Threading.Ipc.Semaphore", function()
    local Semaphore = require "PuRest.Util.Threading.Ipc.Semaphore"

    describe("behaviour", function()
        it("should be correct", function()
            local sem = Semaphore("some_semaphore", {isOwner = true})
            
            assert.are.equal(0, sem.getCounterValue())
            
            assert.are.equal(1, sem.increment())
            assert.are.equal(2, sem.increment())
            
            assert.are.equal(1, sem.decrement())
            assert.are.equal(0, sem.decrement())
            
            assert.has.errors(sem.decrement, string.format("attempted to decrement semaphore counter with id %s below 0", sem.getId()))
            
            assert.are.equal(0, sem.getCounterValue())
                    
            local sem_alt = Semaphore("some_semaphore", {semaphoreId = sem.getId()})

            assert.are.equal(sem.increment(), 1)

            assert.are.equal(sem_alt.getCounterValue(), 1)
            assert.are.equal(sem_alt.decrement(), 0)

            assert.has.errors(sem_alt.destroy, string.format("unable to destroy named mutex '%s' because the current thread is not the mutex owner", "some_semaphore"))

            sem.destroy()

            assert.has.errors(sem.getCounterValue)
            assert.has.errors(sem_alt.getCounterValue)
        end)
    end)
end)
