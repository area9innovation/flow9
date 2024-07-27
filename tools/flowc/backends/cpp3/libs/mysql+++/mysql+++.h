/*

Modern C++ wrapper for MySQL with simple and convenient usage

History:
	VERSION     DATE			CHANGES
	1.2.0.0		2019 Mar 05		Multiple-statement queries
	1.1.0.0		2019 Mar 01		Prepared statements, error support in `result'
	1.0.0.0		2017 Jan 22		First publication

Author:
	Dao Trung Kien			https://github.com/daotrungkien

Contributors:
	Dominik Thalhammer		https://github.com/Thalhammer
	Samuel Borgman			https://github.com/sambrg


Macro Flags:
	NO_STD_OPTIONAL	: using std::experimental::optional by polyfill instead of std::optional in C++17

*/




#pragma once


#ifdef _MSC_VER
#include <winsock.h>
#endif

#include <mysql/mysql.h>
#include <mysql/errmsg.h>

#include <string>
#include <ctime>
#include <mutex>
#include <vector>
#include <memory>
#include <stdarg.h>

#include "polyfill/function_traits.h"
#include "polyfill/datetime.h"


#ifndef NO_STD_OPTIONAL
#include <optional>
#else
#include "polyfill/optional.hpp"
#endif



namespace daotk {

	namespace mysql {

		template <typename Function>
		using function_traits = typename sqlite::utility::function_traits<Function>;

#ifndef NO_STD_OPTIONAL
		template <typename T>
		using optional = typename std::optional<T>;
#else
		template <typename T>
		using optional = typename std::experimental::optional<T>;
#endif


		inline std::string format_string_vargs(const char* fmt_str, va_list args) {
			std::size_t size = 256;
			std::vector<char> buf(size);

			while (true) {
				int needed = std::vsnprintf(&buf[0], size, fmt_str, args);

				if (needed <= (int)size && needed >= 0)
					return &buf[0];

				size = (needed > 0) ? (needed + 1) : (size * 2);
				buf.resize(size);
			}
		}

		inline std::string format_string(const char* fmt_str, ...) {
			va_list vargs;
			va_start(vargs, fmt_str);
			std::string res = format_string_vargs(fmt_str, vargs);
			va_end(vargs);
			return std::move(res);
		}



		class mysql_exception : public std::exception {
		protected:
			unsigned int err_number;
			std::string err_msg;

		public:
			mysql_exception(MYSQL* conn) {
				err_number = mysql_errno(conn);
				err_msg = mysql_error(conn);
			}

			virtual const char* what() const noexcept {
				return err_msg.c_str();
			}

			unsigned int error_number() const {
				return err_number;
			}

			const std::string& error_message() const {
				return err_msg;
			}
		};

		class mysqlpp_exception : public std::exception {
		public:
			enum error_code {
				result_already_fetched,
				empty_result
			};

		protected:
			error_code err;
			std::string err_msg;

		public:
			mysqlpp_exception(error_code _err)
				: err(_err)
			{
				err_msg = format_string("Error: %d", err);
			}

			virtual const char* what() const noexcept {
				return err_msg.c_str();
			}

			const std::string& error_message() const {
				return err_msg;
			}
		};




		class result;
		class connection;


		// iterator class that can be used for iterating returned result rows
		template <typename... Values>
		//class result_iterator : std::iterator<std::random_access_iterator_tag, std::tuple<Values...>, int> {
		class result_iterator : std::iterator_traits<std::tuple<Values...>> {
		protected:
			result* res;
			std::shared_ptr<std::tuple<Values...>> data;
			std::size_t row_index;


			template <int I>
			typename std::enable_if<(I > 0), void>::type
				fetch_impl();

			template <int I>
			typename std::enable_if<(I == 0), void>::type
				fetch_impl();

			void fetch();

			void set_index(std::size_t i) {
				row_index = i;
				data.reset();
			}

		public:
			result_iterator() {
				res = nullptr;
				row_index = 0;
			}

			result_iterator(result* _res, std::size_t _row_index)
				: res(_res), row_index(_row_index)
			{ }

			result_iterator(result_iterator& itr) {
				res = itr.res;
				row_index = itr.row_index;
				data = itr.data;
			}

			result_iterator(result_iterator&& itr) {
				res = itr.res;
				row_index = itr.row_index;
				data = std::move(itr.data);
			}

			void operator =(result_iterator& itr) {
				res = itr.res;
				row_index = itr.row_index;
				data = itr.data;
			}

			void operator =(result_iterator&& itr) {
				res = itr.res;
				row_index = itr.row_index;
				data = std::move(itr.data);
			}

			result_iterator& operator ++() {
				set_index(row_index + 1);
				return *this;
			}

			result_iterator operator ++(int) {
				result_iterator tmp(*this);
				set_index(row_index + 1);
				return tmp;
			}

			result_iterator& operator --() {
				set_index(row_index - 1);
				return *this;
			}

			result_iterator operator --(int) {
				result_iterator tmp(*this);
				set_index(row_index - 1);
				return tmp;
			}

			result_iterator& operator +=(int n) {
				set_index(row_index + n);
				return *this;
			}

			result_iterator& operator -=(int n) {
				set_index(row_index - n);
				return *this;
			}

			result_iterator operator +(int n) {
				return result_iterator(res, row_index + n);
			}

			result_iterator operator -(int n) {
				return result_iterator(res, row_index - n);
			}

			bool operator == (const result_iterator& itr) const {
				return row_index == itr.row_index;
			}
			bool operator != (const result_iterator& itr) const {
				return row_index != itr.row_index;
			}
			bool operator > (const result_iterator& itr) const {
				return row_index > itr.row_index;
			}
			bool operator < (const result_iterator& itr) const {
				return row_index < itr.row_index;
			}
			bool operator >= (const result_iterator& itr) const {
				return row_index >= itr.row_index;
			}
			bool operator <= (const result_iterator& itr) const {
				return row_index <= itr.row_index;
			}

			std::tuple<Values...>& operator *() {
				if (!data) fetch();
				return *data;
			}

			std::tuple<Values...>* operator ->() {
				if (!data) fetch();
				return data.get();
			}
		};


		// container-like result class
		template <typename... Values>
		class result_containter {

		public:
			using tuple_type = std::tuple<Values...>;

			friend class result;

		protected:
			result* res;

			result_containter(result* _res)
				: res(_res)
			{}

		public:
			result_iterator<Values...> begin();
			result_iterator<Values...> end();
		};

		//using field = std::pair<std::string, enum_field_types>;
		struct field {
			std::string name;
			enum_field_types type;
		};

		// result fetching
		class result {

			friend class connection;

		protected:
			MYSQL* my_conn = nullptr;
			bool fetched = false;

			// used only when `mode == mode_fetch'
			std::vector< std::vector<std::string> > rows;
			std::vector< std::vector<std::string> >::iterator current_row_itr;
			std::vector<field> fields_;


			result(MYSQL* _my_conn, bool fetch_now = false)
				: my_conn(_my_conn)
			{
				if (fetch_now) fetch();
			}

			void check_condition() {
				if (!fetched) fetch();
			}



			template <typename Function, std::size_t Index>
			using nth_argument_type = typename function_traits<Function>::template argument<Index>;

			template <typename Function, typename... Values>
			typename std::enable_if<(sizeof...(Values) < function_traits<Function>::arity), bool>::type
				bind_and_call(Function&& callback, Values&&... values) {
				nth_argument_type<Function, sizeof...(Values)> value;
				get_value(sizeof...(Values), value);

				return bind_and_call(callback, std::forward<Values&&>(values)..., std::move(value));
			}

			template <typename Function, typename... Values>
			typename std::enable_if<(sizeof...(Values) == function_traits<Function>::arity), bool>::type
				bind_and_call(Function&& callback, Values&&... values) {
				return callback(std::forward<Values&&>(values)...);
			}

		public:
			result(const result& r) = delete;
			void operator =(const result& r) = delete;

			result() {
			}

			result(result&& r) noexcept {
				my_conn = r.my_conn;
				fetched = r.fetched;

				rows = std::move(r.rows);
				fields_ = std::move(r.fields_);
				current_row_itr = r.current_row_itr;

				r.my_conn = nullptr;
				r.fetched = false;
			}

			void operator =(result&& r) noexcept {
				free();

				my_conn = r.my_conn;
				fetched = r.fetched;

				rows = std::move(r.rows);\
				fields_ = std::move(r.fields_);
				current_row_itr = r.current_row_itr;

				r.my_conn = nullptr;
				r.fetched = false;
			}

			virtual ~result() {
				free();
			}

			void free() {
				if (!fetched) {
					if (my_conn != nullptr) {
						// mysql_use_result must be called for SELECT, SHOW,...
						// https://dev.mysql.com/doc/refman/8.0/en/mysql-use-result.html
						MYSQL_RES* _res = mysql_use_result(my_conn);
						if (_res != nullptr) mysql_free_result(_res);
					}
				}
				else {
					rows.clear();
				}

				my_conn = nullptr;
				fetched = false;
			}

			// store result internally for further queries to avoid Error #2014 (Commands out of sync)
			void fetch() {
				if (fetched) throw mysqlpp_exception(mysqlpp_exception::result_already_fetched);
				MYSQL_RES* _res = mysql_store_result(my_conn);

				auto num_fields = mysql_num_fields(_res);
				MYSQL_FIELD* fs = mysql_fetch_field(_res);
				for (auto i = 0; i < num_fields; ++ i) {
					fields_.emplace_back(
						std::move(std::string(fs[i].name, fs[i].name_length)),
						fs[i].type
					);
				}

				if (num_fields > 0) {
					while (MYSQL_ROW _row = mysql_fetch_row(_res)) {
						auto fetch_lengths = mysql_fetch_lengths(_res);
						if (fetch_lengths == nullptr) throw mysql_exception{ my_conn };

						std::vector<std::string> rowdata;
						for (unsigned int i = 0; i < num_fields; i++) {
							rowdata.push_back(std::string(_row[i], fetch_lengths[i]));
						}
						rows.push_back(rowdata);
					}

					current_row_itr = rows.begin();
				}

				mysql_free_result(_res);

				fetched = true;
			}

			// return number of rows
			std::size_t count() {
				check_condition();

				return rows.size();
			}

			// return number of fields
			const std::vector<field>& fields() {
				check_condition();

				return fields_;
			}

			// return true if no data was returned
			bool is_empty() {
				return count() == 0;
			}

			// return true if passed the last row
			bool eof() {
				check_condition();

				return current_row_itr == rows.end();
			}

			// go to first row
			void reset() {
				seek(0);
			}

			// go to nth row
			void seek(std::size_t n) {
				check_condition();

				current_row_itr = rows.begin() + n;
			}

			// go to next row
			void next() {
				check_condition();

				if (!eof()) {
					++current_row_itr;
				}
			}

			// go to previous row
			void prev() {
				check_condition();

				current_row_itr--;
			}

			// return curent row index
			std::size_t tell() {
				check_condition();

				return current_row_itr - rows.begin();
			}

			// iterate through all rows, each time execute the callback function
			template <typename Function>
			int each(Function callback) {
				reset();

				int count = 0;
				while (!eof()) {
					count++;
					if (!bind_and_call(callback)) break;
					next();
				}

				return count;
			}

			// create an object that can be used to iterate through the rows like STL containers
			template <typename... Values>
			result_containter<Values...> as_container() {
				return result_containter<Values...>{this};
			}




			// get-value functions in different ways and types...

			const std::string& get_field(int i) {
				check_condition();

				if (current_row_itr == rows.end()) {
					static std::string s;
					return s;
				}
				return (*current_row_itr).at(i);
			}

			const char* get_field_data(int i) {
				check_condition();

				if (current_row_itr == rows.end() || (*current_row_itr)[i].empty()) return nullptr;
				return (*current_row_itr)[i].c_str();
			}

			bool get_value(int i, bool& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				try {
					value = (std::stoi(s) != 0);
					return true;
				}
				catch (std::exception&) {
					return false;
				}
			}

			bool get_value(int i, int& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				try {
					value = std::stoi(s);
					return true;
				}
				catch (std::exception&) {
					return false;
				}
			}

			bool get_value(int i, unsigned int& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				try {
					value = (unsigned int)std::stoul(s);
					return true;
				}
				catch (std::exception&) {
					return false;
				}
			}

			bool get_value(int i, long& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				try {
					value = std::stol(s);
					return true;
				}
				catch (std::exception&) {
					return false;
				}
			}

			bool get_value(int i, unsigned long& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				try {
					value = std::stoul(s);
					return true;
				}
				catch (std::exception&) {
					return false;
				}
			}

			bool get_value(int i, long long& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				try {
					value = std::stoll(s);
					return true;
				}
				catch (std::exception&) {
					return false;
				}
			}

			bool get_value(int i, unsigned long long& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				try {
					value = std::stoull(s);
					return true;
				}
				catch (std::exception&) {
					return false;
				}
			}

			bool get_value(int i, float& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				try {
					value = std::stof(s);
					return true;
				}
				catch (std::exception&) {
					return false;
				}
			}

			bool get_value(int i, double& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				try {
					value = std::stod(s);
					return true;
				}
				catch (std::exception&) {
					return false;
				}
			}

			bool get_value(int i, long double& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				try {
					value = std::stold(s);
					return true;
				}
				catch (std::exception&) {
					return false;
				}
			}

			bool get_value(int i, std::string& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				value = s;
				return true;
			}

			bool get_value(int i, datetime& value) {
				const char* s = get_field_data(i);
				if (s == nullptr) return false;

				value.from_sql(s);
				return true;
			}

			template <typename Value>
			bool get_value(Value& value) {
				return get_value(0, value);
			}

			template <typename Value>
			Value get_value(int i = 0) {
				Value v;
				get_value(i, v);
//				if (!get_value(i, v)) throw mysqlpp_exception(mysqlpp_exception::empty_result);
				return std::move(v);
			}

			template <typename Value>
			void get_value(int i, optional<Value>& value) {
				Value v;
				if (get_value(i, v)) value = v;
			}

			template <typename Value>
			void get_value(optional<Value>& value) {
				get_value(0, value);
			}

			template <typename Value>
			Value operator[](int i) {
				Value v;
				if (!get_value(i, v)) throw mysqlpp_exception(mysqlpp_exception::empty_result);
				return std::move(v);
			}


		protected:
			template <typename Value>
			void fetch_impl(int i, Value& value) {
				get_value(i, value);
			}

			template <typename Value, typename... Values>
			void fetch_impl(int i, Value& value, Values&... values) {
				get_value(i, value);
				fetch_impl(i + 1, std::forward<Values&>(values)...);
			}

		public:
			// get data from every fields of the current row
			template <typename... Values>
			bool fetch(Values&... values) {
				check_condition();

				if (current_row_itr == rows.end()) return false;

				fetch_impl(0, std::forward<Values&>(values)...);
				return true;
			}
		};


		struct connect_options {
			connect_options(
				const std::string &_server = "",
				const std::string _username = "",
				const std::string _password = "",
				const std::string _dbname = "", 
				unsigned int _timeout = 0,
				bool _autoreconnect = false,
				const std::string _init_command = "",
				const std::string _charset = "",
				unsigned int _port = 0,
				unsigned long _client_flag = 0
			) :	server(_server),
				username(_username),
				password(_password),
				dbname(_dbname),
				timeout(_timeout),
				autoreconnect(_autoreconnect),
				init_command(_init_command),
				charset(_charset),
				port(_port),
				client_flag(_client_flag)
			{}

			std::string server;
			std::string username;
			std::string password;
			std::string dbname;
			unsigned int timeout;
			bool autoreconnect;
			std::string init_command;
			std::string charset;
			unsigned int port;
			unsigned long client_flag;
		};


		// database connection and query...
		class connection : public std::enable_shared_from_this<connection> {

			friend class prepared_stmt;

		protected:
			MYSQL* my_conn;
			mutable std::mutex mutex;	// mutex needs to be locked while using a prepared stmt

		public:
			// open a connection (close the old one if already open), return true if successful
			bool open(const connect_options& options) {
				if (is_open()) close();

				std::lock_guard<std::mutex> mg(mutex);

				my_conn = mysql_init(nullptr);
				if (my_conn == nullptr) return false;

				if (options.autoreconnect) { 
					bool b = options.autoreconnect;
					mysql_options(my_conn, MYSQL_OPT_RECONNECT, &b);
				}
				if (!options.charset.empty()) mysql_options(my_conn, MYSQL_SET_CHARSET_NAME, options.charset.c_str());
				if (!options.init_command.empty()) mysql_options(my_conn, MYSQL_INIT_COMMAND, options.init_command.c_str());
				if (options.timeout > 0) mysql_options(my_conn, MYSQL_OPT_CONNECT_TIMEOUT, (char*)&options.timeout);

				if (nullptr == mysql_real_connect(my_conn, options.server.c_str(), options.username.c_str(), options.password.c_str(), options.dbname.c_str(), options.port, nullptr, options.client_flag)) {
					mysql_close(my_conn);
					my_conn = nullptr;
					return false;
				}

				return true;
			}

			// open a connection (close the old one if already open), return true if successful
			bool open(std::string server, std::string username, std::string password, std::string dbname = "", unsigned int timeout = 0) {
				return open(connect_options(server, username, password, dbname, timeout));
			}

			connection()
				: my_conn(nullptr)
			{ }

			connection(const connect_options& opts)
				: my_conn(nullptr)
			{
				open(opts);
			}

			connection(std::string server, std::string username, std::string password, std::string dbname = "", unsigned int timeout = 0)
				: my_conn(nullptr)
			{
				open(server, username, password, dbname, timeout);
			}

			void close() {
				std::lock_guard<std::mutex> mg(mutex);

				if (my_conn != nullptr) {
					mysql_close(my_conn);
					my_conn = nullptr;
				}
			}

			virtual ~connection() {
				close();
			}

			operator bool() const {
				return is_open();
			}

			bool is_open() const {
				if(my_conn == nullptr) return false;
				std::lock_guard<std::mutex> mg(mutex);
				return mysql_ping(my_conn) == 0;
			}

			// raw MySQL connection in case needed
			MYSQL* get_raw_connection() const {
				return my_conn;
			}


			// wrapping of some functions

			int set_server_option(enum_mysql_set_option option) {
				return mysql_set_server_option(my_conn, option);
			}

			unsigned long long last_insert_id() const {
				return mysql_insert_id(my_conn);
			}

			unsigned long long affected_rows() const {
				return mysql_affected_rows(my_conn);
			}

			unsigned int error_code() const {
				return mysql_errno(my_conn);
			}

			const char* error_message() const {
				return mysql_error(my_conn);
			}

		public:
			// execute query given by string and return result
			result query(const std::string& query_str) {
				std::lock_guard<std::mutex> mg(mutex);

				int ret = mysql_real_query(my_conn, query_str.c_str(), query_str.length());
				if (ret != 0) throw mysql_exception{ my_conn };

				return result{ my_conn, false };
			}

			// execute query with printf-style substitutions and return result
			template <typename... Values>
			result query(const std::string& fmt_str, Values... values) {
				return query( format_string(fmt_str.c_str(), std::forward<Values>(values)...) );
			}

			// multiple statement query execution
			std::vector<result> mquery(const std::string& query_str) {
				std::lock_guard<std::mutex> mg(mutex);

				int ret = mysql_real_query(my_conn, query_str.c_str(), query_str.length());
				if (ret != 0) throw mysql_exception{ my_conn };

				std::vector<result> res;
				do {
					res.push_back(result{ my_conn, true });
				} while (mysql_next_result(my_conn) == 0);
				return std::move(res);
			}

			// multiple statement query execution with printf-style substitutions and return result
			template <typename... Values>
			std::vector<result> mquery(const std::string& fmt_str, Values... values) {
				return mquery(format_string(fmt_str.c_str(), std::forward<Values>(values)...));
			}

			// like query(), but no result returned
			void exec(const std::string& query_str) {
				std::lock_guard<std::mutex> mg(mutex);

				int ret = mysql_real_query(my_conn, query_str.c_str(), query_str.length());
				if (ret != 0) throw mysql_exception{ my_conn };

				// mysql_use_result must be called for SELECT, SHOW,...
				// https://dev.mysql.com/doc/refman/8.0/en/mysql-use-result.html
				MYSQL_RES* myres = mysql_use_result(my_conn);
				if (myres != nullptr) mysql_free_result(myres);
			}

			// like query(), but no result returned
			template <typename... Values>
			void exec(const std::string& fmt_str, Values... values) {
				exec(format_string(fmt_str.c_str(), std::forward<Values>(values)...) );
			}
		};






		template <typename... Values>
		template <int I>
		typename std::enable_if<(I > 0), void>::type
			result_iterator<Values...>::fetch_impl() {
			res->get_value(I, std::get<I>(*data));
			fetch_impl<I - 1>();
		}

		template <typename... Values>
		template <int I>
		typename std::enable_if<(I == 0), void>::type
			result_iterator<Values...>::fetch_impl() {
			res->get_value(I, std::get<I>(*data));
		}

		template <typename... Values>
		void result_iterator<Values...>::fetch() {
			res->seek(row_index);
			data = std::make_shared<std::tuple<Values...>>();
			fetch_impl<sizeof...(Values)-1>();
		}


		template <typename... Values>
		result_iterator<Values...> result_containter<Values...>::begin() {
			return result_iterator<Values...>{res, 0};
		}

		template <typename... Values>
		result_iterator<Values...> result_containter<Values...>::end() {
			return result_iterator<Values...>{res, res->count()};
		}

		namespace stmt_bind_detail {
			struct my_bind_base {
				MYSQL_BIND* bind;
				virtual ~my_bind_base() {}
				// Called before executing the statement
				virtual void pre_execute() {}
				// Called after executing the statement
				virtual void post_execute() {}
				// Called before fetching result
				virtual void pre_fetch() {}
				// If post_fetch returns true, we call mysql_stmt_fetch_column again (for example for strings)
				virtual bool post_fetch() { return false; }
				// Only called of post_fetch returned true, after mysql_stmt_fetch_column was called
				virtual void post_refetch() {}
			};

			template<typename T>
			struct my_bind : my_bind_base {
			};

			template<enum_field_types mysql_type, typename T>
			struct my_number_bind : my_bind_base {
				T* data;

				virtual void pre_execute() override { update(); }
				virtual void pre_fetch() override { update(); }

				void update() {
					memset(bind, 0x00, sizeof(MYSQL_BIND));
					bind->buffer = data;
					bind->buffer_type = mysql_type;
					bind->is_null_value = false;
					bind->is_unsigned = std::is_unsigned<T>::value;
				}
			};

			template<enum_field_types mysql_type, typename T>
			struct my_optional_number_bind : my_bind_base {
				optional<T>* data;
				T pdata;

				virtual void pre_execute() override {
					memset(bind, 0x00, sizeof(MYSQL_BIND));
					if (data->has_value()) {
						pdata = data->value();
					}
					bind->buffer = &pdata;
					bind->buffer_type = mysql_type;
					bind->is_null_value = data->has_value();
					bind->is_unsigned = std::is_unsigned<T>::value;
				}

				virtual void pre_fetch() override {
					memset(bind, 0x00, sizeof(MYSQL_BIND));
					bind->buffer = &pdata;
					bind->buffer_type = mysql_type;
					bind->is_unsigned = std::is_unsigned<T>::value;
					bind->is_null = &bind->is_null_value;
				}

				virtual bool post_fetch() override {
					if (bind->is_null_value) {
						data->reset();
					}
					else {
						*data = pdata;
					}
					return false;
				}
			};

			template<> struct my_bind<uint8_t> : my_number_bind<MYSQL_TYPE_TINY, uint8_t> {};
			template<> struct my_bind<int8_t> : my_number_bind<MYSQL_TYPE_TINY, int8_t> {};
			template<> struct my_bind<uint16_t> : my_number_bind<MYSQL_TYPE_SHORT, uint16_t> {};
			template<> struct my_bind<int16_t> : my_number_bind<MYSQL_TYPE_SHORT, int16_t> {};
			template<> struct my_bind<uint32_t> : my_number_bind<MYSQL_TYPE_LONG, uint32_t> {};
			template<> struct my_bind<int32_t> : my_number_bind<MYSQL_TYPE_LONG, int32_t> {};
			template<> struct my_bind<uint64_t> : my_number_bind<MYSQL_TYPE_LONGLONG, uint64_t> {};
			template<> struct my_bind<int64_t> : my_number_bind<MYSQL_TYPE_LONGLONG, int64_t> {};
			template<> struct my_bind<float> : my_number_bind<MYSQL_TYPE_FLOAT, float> {};
			template<> struct my_bind<double> : my_number_bind<MYSQL_TYPE_DOUBLE, double> {};

			template<> struct my_bind<bool> : my_number_bind<MYSQL_TYPE_TINY, bool> {};

			template<> struct my_bind<optional<uint8_t>> : my_optional_number_bind<MYSQL_TYPE_TINY, uint8_t> {};
			template<> struct my_bind<optional<int8_t>> : my_optional_number_bind<MYSQL_TYPE_TINY, int8_t> {};
			template<> struct my_bind<optional<uint16_t>> : my_optional_number_bind<MYSQL_TYPE_SHORT, uint16_t> {};
			template<> struct my_bind<optional<int16_t>> : my_optional_number_bind<MYSQL_TYPE_SHORT, int16_t> {};
			template<> struct my_bind<optional<uint32_t>> : my_optional_number_bind<MYSQL_TYPE_LONG, uint32_t> {};
			template<> struct my_bind<optional<int32_t>> : my_optional_number_bind<MYSQL_TYPE_LONG, int32_t> {};
			template<> struct my_bind<optional<uint64_t>> : my_optional_number_bind<MYSQL_TYPE_LONGLONG, uint64_t> {};
			template<> struct my_bind<optional<int64_t>> : my_optional_number_bind<MYSQL_TYPE_LONGLONG, int64_t> {};
			template<> struct my_bind<optional<float>> : my_optional_number_bind<MYSQL_TYPE_FLOAT, float> {};
			template<> struct my_bind<optional<double>> : my_optional_number_bind<MYSQL_TYPE_DOUBLE, double> {};

			template<> struct my_bind<optional<bool>> : my_optional_number_bind<MYSQL_TYPE_TINY, bool> {};

			template<>
			struct my_bind<std::string> : my_bind_base {
				std::string* data;
				virtual void pre_execute() override {
					memset(bind, 0x00, sizeof(MYSQL_BIND));
					if (data != nullptr) {
						bind->buffer = (void*)data->data();
						bind->buffer_length = data->size();
						bind->buffer_type = MYSQL_TYPE_STRING;
						bind->is_null_value = false;
						bind->length_value = data->size();
					}
					else {
						bind->buffer_type = MYSQL_TYPE_NULL;
					}
					bind->length = &bind->length_value;
					bind->is_null = &bind->is_null_value;
				}
				virtual void pre_fetch() override {
					memset(bind, 0x00, sizeof(MYSQL_BIND));
					bind->buffer_type = MYSQL_TYPE_STRING;
					// libmysql debug build breaks if buffer_length is 0
					// This buffer is enougth to store all doubles as strings
					data->resize(128);
					bind->buffer = (void*)data->data();
					bind->buffer_length = data->size();
					bind->is_null_value = false;
					bind->length = &bind->length_value;
					bind->is_null = &bind->is_null_value;
				}
				virtual bool post_fetch() override {
					if (bind->length_value > 0) {
						data->resize(bind->length_value);
						bind->buffer = (void*)data->data();
						bind->buffer_length = data->size();
						return true;
					}
					else {
						data->clear();
						return false;
					}
				}
			};

			template<>
			struct my_bind<optional<std::string>> : my_bind_base {
				optional<std::string>* data;

				virtual void pre_execute() override {
					memset(bind, 0x00, sizeof(MYSQL_BIND));
					if (data->has_value()) {
						bind->buffer = (void*)data->value().data();
						bind->buffer_length = data->value().size();
						bind->buffer_type = MYSQL_TYPE_STRING;
						bind->is_null_value = false;
						bind->length_value = bind->buffer_length;
					}
					else {
						bind->is_null_value = true;
					}
					bind->length = &bind->length_value;
					bind->is_null = &bind->is_null_value;
				}
				virtual void pre_fetch() override {
					memset(bind, 0x00, sizeof(MYSQL_BIND));
					bind->buffer_type = MYSQL_TYPE_STRING;

					// Init temp
					*data = std::string();

					// libmysql debug build breaks if buffer_length is 0
					auto& pdata = data->value();
					pdata.resize(1);
					bind->buffer = (void*)pdata.data();
					bind->buffer_length = pdata.size();
					bind->is_null_value = false;
					bind->length = &bind->length_value;
					bind->is_null = &bind->is_null_value;
				}

				virtual bool post_fetch() override {
					if (bind->is_null_value) {
						data->reset();
						return false;
					}
					else {
						auto& pdata = data->value();
						if (bind->length_value > 0) {
							pdata.resize(bind->length_value);
							bind->buffer = (void*)pdata.data();
							bind->buffer_length = pdata.size();
							return true;
						}
						else {
							pdata.clear();
							return false;
						}
					}
				}
			};
		}

		class prepared_stmt : public std::enable_shared_from_this<prepared_stmt> {
		private:
			connection& con;
			std::unique_ptr<MYSQL_STMT, void(*)(MYSQL_STMT*)> stmt;

			class mysql_bind_set {
			private:
				std::vector<MYSQL_BIND> _binds_mysql;
				std::vector<std::unique_ptr<stmt_bind_detail::my_bind_base>> _wrappers;

			public:
				mysql_bind_set(std::size_t size) {
					_binds_mysql.resize(size);
					_wrappers.resize(size);
				}

				MYSQL_BIND* binds() {
					return (MYSQL_BIND*)_binds_mysql.data();
				}

				std::size_t size() {
					return _wrappers.size();
				}


				void pre_execute() {
					for (auto& e : _wrappers)
						e->pre_execute();
				}

				void post_execute() {
					for (auto& e : _wrappers)
						e->post_execute();
				}

				void pre_fetch() {
					for (auto& e : _wrappers)
						e->pre_fetch();
				}

				std::vector<std::size_t> post_fetch() {
					std::vector<std::size_t> res;
					for (std::size_t i = 0; i < _wrappers.size(); i++) {
						if (_wrappers[i]->post_fetch())
							res.push_back(i);
					}
					return res;
				}

				void post_refetch(const std::vector<std::size_t>& items) {
					for (auto& e : items)
						_wrappers[e]->post_refetch();
				}


				template<typename T>
				void set_variable(std::size_t idx, T& arg) {
					if (idx >= _wrappers.size())
						throw std::out_of_range("Invalid binding index");
					auto wrap = std::make_unique<stmt_bind_detail::my_bind<T>>();
					wrap->data = &arg;
					wrap->bind = &_binds_mysql[idx];
					_wrappers[idx] = std::move(wrap);
				}

				template<typename... Args>
				void bind_variables(const Args &... args) {
					bind_variables_impl(0, args...);
				}
				template<typename T>
				void bind_variables(std::vector<T>& args) {
					for (auto i = 0; i < args.size(); ++ i) {
						set_variable<T>(i, args[i]);
					}
				}

			private:
				template<typename T>
				void bind_variables_impl(std::size_t idx, const T& arg) {
					this->set_variable(idx, const_cast<T&>(arg));
				}

				template<typename T1, typename... Args>
				void bind_variables_impl(std::size_t idx, const T1& arg1, const Args &... args) {
					bind_variables_impl(idx, arg1);
					bind_variables_impl(idx + 1, args...);
				}
			};

			mysql_bind_set param_binds;
			mysql_bind_set result_binds;

			std::vector<field> fields_;

		public:
			prepared_stmt(connection& pcon, const std::string& query)
				: con(pcon), stmt(nullptr, [](MYSQL_STMT* stmt) { mysql_stmt_close(stmt); }), param_binds(0), result_binds(0)
			{
				std::unique_lock<std::mutex> lck(con.mutex);
				stmt.reset(mysql_stmt_init(con.my_conn));

				if (!stmt) // Out of memory is the only returned error
					throw std::bad_alloc();

				if (mysql_stmt_prepare(stmt.get(), query.c_str(), query.size()))
					throw std::runtime_error(std::string("Failed to prepare stmt: ") + mysql_stmt_error(stmt.get()));

				auto param_count = mysql_stmt_param_count(stmt.get());
				param_binds = mysql_bind_set(param_count);

				std::unique_ptr<MYSQL_RES, decltype(&mysql_free_result)> meta(mysql_stmt_result_metadata(stmt.get()), mysql_free_result);
				if (meta) {
					// Not all queries produce a result set
					auto result_count = mysql_num_fields(meta.get());
					result_binds = mysql_bind_set(result_count);
					auto num_fields = mysql_num_fields(meta.get());
					MYSQL_FIELD* fs = mysql_fetch_field(meta.get());
					for (auto i = 0; i < num_fields; ++ i) {
						fields_.emplace_back(
							std::move(std::string(fs[i].name, fs[i].name_length)),
							fs[i].type
						);
					}
				}
			}

			// query with printf-style substitutions
			template <typename... Values>
			prepared_stmt(connection& pcon, const std::string& fmt_str, Values... values)
				: prepared_stmt(pcon, format_string(fmt_str.c_str(), std::forward<Values>(values)...))
			{}

			virtual ~prepared_stmt() {
				std::unique_lock<std::mutex> lck(con.mutex);
				stmt.reset();
			}

			bool execute() {
				std::unique_lock<std::mutex> lck(con.mutex);
				param_binds.pre_execute();
				if (mysql_stmt_bind_param(stmt.get(), param_binds.binds()))
					return false;
				if (mysql_stmt_execute(stmt.get()))
					return false;
				param_binds.post_execute();
				return true;
			}

			const std::vector<field>& fields() { return fields_; }

			template<typename... Args>
			void bind_param(const Args &... args) {
				param_binds.bind_variables(args...);
			}
			template<typename T>
			void bind_param(std::vector<T>& args) {
				param_binds.bind_variables(args);
			}

			template<typename... Args>
			void bind_result(Args &... args) {
				result_binds.bind_variables(args...);
			}
			template<typename T>
			void bind_result(std::vector<T>& args) {
				result_binds.bind_variables(args);
			}

			bool fetch() {
				std::unique_lock<std::mutex> lck(con.mutex);
				result_binds.pre_fetch();
				if (mysql_stmt_bind_result(stmt.get(), result_binds.binds()))
					return false;
				int rc = mysql_stmt_fetch(stmt.get());
				if (rc == MYSQL_DATA_TRUNCATED || rc == 0) {
					auto refetch = result_binds.post_fetch();
					for (auto& i : refetch) {
						if (mysql_stmt_fetch_column(stmt.get(), &result_binds.binds()[i], (unsigned int)i, 0))
							return false;
					}
					result_binds.post_refetch(refetch);
					return true;
				}
				else return false;
			}

			unsigned int error_code() const {
				return mysql_stmt_errno(stmt.get());
			}

			const char* error_message() const {
				return mysql_stmt_error(stmt.get());
			}
		};
	}
}
