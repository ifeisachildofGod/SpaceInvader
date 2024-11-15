local function StateMachine(statesTbl)
    local self = {
        setState = function (self, state)
            self.state = state
            for _, s in ipairs(statesTbl) do
                self[s] = self.state == s
            end
        
        end
    }
    
    self.state = nil

    for _, state in ipairs(statesTbl) do
        self[state] = self.state == state
    end

    return self
end

return StateMachine