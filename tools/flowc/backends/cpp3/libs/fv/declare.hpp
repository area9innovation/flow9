#ifndef __FV_DECLARE_HPP__
#define __FV_DECLARE_HPP__



#ifndef FV_USE_BOOST_ASIO
#ifndef ASIO_HAS_CO_AWAIT
#define ASIO_HAS_CO_AWAIT
#endif
#include <asio.hpp>
#include <asio/ssl.hpp>
#else
#ifndef BOOST_ASIO_HAS_CO_AWAIT
#define BOOST_ASIO_HAS_CO_AWAIT
#endif
#include <boost/asio.hpp>
#include <boost/asio/ssl.hpp>
#endif



namespace fv {
#ifdef FV_USE_BOOST_ASIO
namespace asio = boost::asio;
#define Task boost::asio::awaitable
#else
#define Task asio::awaitable
#endif

using Tcp = asio::ip::tcp;
using Udp = asio::ip::udp;
namespace Ssl = asio::ssl;
using IoContext = asio::io_context;
using SocketBase = asio::socket_base;
using SslCheckCb = std::function<bool (bool, Ssl::verify_context &)>;
inline decltype (asio::use_awaitable) &UseAwaitable = asio::use_awaitable;
using TimeSpan = std::chrono::system_clock::duration;
}



#endif //__FV_DECLARE_HPP__
