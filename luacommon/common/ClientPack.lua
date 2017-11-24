require "common/class"
require "common/PackParse"


-- 客户端发gate心跳包 
ClientToGate_Heartbeat = class(BasePack)
function ClientToGate_Heartbeat:ctor()
	self._head_ = 0x0064
	self._field_ = {
	}
	self:InitField()
end
-- gate发客户端心跳包 
GateToClient_Heartbeat = class(BasePack)
function GateToClient_Heartbeat:ctor()
	self._head_ = 0x0065
	self._field_ = {
	}
	self:InitField()
end
setPackInfo(0x0064, ClientToGate_Heartbeat)
setPackInfo(0x0065, GateToClient_Heartbeat)