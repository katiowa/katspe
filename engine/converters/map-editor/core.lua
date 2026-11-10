-- Funções utilitárias globais da Engine. (Não apague)

function log(msg)
    if EngineAPI and EngineAPI.log then
        EngineAPI.log(tostring(msg))
    else
        print(tostring(msg))
    end
end
