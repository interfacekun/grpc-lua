#include "BindClientAsyncReaderWriter.h"

#include "impl/CbWrapper.h"
#include "impl/GetTimeoutMs.h"

#include <grpc_cb_core/client/client_async_reader_writer.h>  // for ClientAsyncReaderWriter
#include <grpc_cb_core/common/status.h>  // for Status
#include <LuaIntf/LuaIntf.h>

#include <string>

using namespace grpc_cb_core;
using namespace LuaIntf;

namespace {

ClientAsyncReaderWriter GetClientAsyncReaderWriter(const ChannelSptr& pChannel,
    const std::string& sMethod, const CompletionQueueSptr& pCq,
    const LuaRef& timeoutSec, const LuaRef& luaStatusCb)
{
    assert(pCq);
    int64_t nTimeoutMs = impl::GetTimeoutMs(timeoutSec);
    StatusCb cbStatus = CbWrapper::WrapLuaStatusCb(luaStatusCb);
    return ClientAsyncReaderWriter(pChannel, sMethod, pCq,
                                   nTimeoutMs, cbStatus);
}

// return string|nil, nil means error or end
//LuaRef ReadOne(const ClientSyncReaderWriter& rw, lua_State* L)
//{
//    assert(L);
//    std::string sMsg;
//    if (rw.ReadOne(&sMsg))
//        return LuaRef::fromValue(L, sMsg);
//    return LuaRef(L, nullptr);
//}

}  // namespace

namespace bind {

void BindClientAsyncReaderWriter(const LuaRef& mod)
{
    lua_State* L = mod.state();
    assert(L);
    LuaBinding(mod).beginClass<ClientAsyncReaderWriter>("ClientAsyncReaderWriter")
        .addFactory(&GetClientAsyncReaderWriter)
        //.addFunction("read_one",
        //    [L](const ClientSyncReaderWriter* pRdWr) {
        //        assert(pRdWr);
        //        return ReadOne(*pRdWr, L);
        //    })
        .addFunction("write", &ClientAsyncReaderWriter::Write)
        .addFunction("close_writing", &ClientAsyncReaderWriter::CloseWriting)
    .endClass();
}  // BindClientAsyncReaderWriter()

}  // namespace bind
