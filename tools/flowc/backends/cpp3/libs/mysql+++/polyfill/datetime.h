#pragma once


#include <sstream>
#include <iomanip>
#include <time.h>
#include <string.h>


namespace daotk {
	namespace mysql {

		class datetime {
		public:
			int year, month, day, hour, minute;
			float sec;
			bool with_date, with_time;

		public:
			datetime()
				: with_date(false), with_time(false)
			{ }

			datetime(time_t ts) {
				tm t;
#ifdef _MSC_VER
				localtime_s(&t, &ts);
#else
				localtime_r(&ts, &t);
#endif
				year = t.tm_year;
				month = t.tm_mon;
				day = t.tm_mday;
				hour = t.tm_hour;
				minute = t.tm_min;
				sec = (float)t.tm_sec;
			}

			datetime(int _year, int _mon, int _day, int _hour, int _min, float _sec)
				: year(_year), month(_mon), day(_day), hour(_hour), minute(_min), sec(_sec),
				with_date(true), with_time(true)
			{ }

			datetime(int _year, int _mon, int _day)
				: year(_year), month(_mon), day(_day),
				with_date(true), with_time(false)
			{ }

			datetime(int _hour, int _min, float _sec)
				: hour(_hour), minute(_min), sec(_sec),
				with_date(false), with_time(true)
			{ }

			void from_sql(const char* sql) {
				with_date = (strchr(sql, '-') != nullptr);
				with_time = (strchr(sql, ':') != nullptr);

				std::istringstream str(sql);
				if (with_date) {
					str >> year;

					str.ignore();
					str >> month;

					str.ignore();
					str >> day;

					str.ignore();
				}

				if (with_time) {
					str >> hour;

					str.ignore();
					str >> minute;

					str.ignore();
					str >> sec;
				}
			}
			
			std::string to_sql(bool with_sec_frac = true) const {
				std::ostringstream str;

				if (with_date) {
					str << year << '-'
						<< std::setfill('0') << std::setw(2)
						<< month << '-'
						<< day;

					if (with_time) str << ' ';
				}

				if (with_time) {
					str << std::setfill('0') << std::setw(2)
						<< hour << ':'
						<< minute << ':';

					if (with_sec_frac) {
						str << std::setprecision(3) << std::setw(6)
							<< sec;
					}
					else {
						str << (int)sec;
					}
				}

				return str.str();
			}

			operator time_t() const {
				tm t;
				t.tm_year = with_date ? year : 0;
				t.tm_mon = with_date ? month : 0;
				t.tm_mday = with_date ? day : 0;
				t.tm_hour = with_time ? hour : 0;
				t.tm_min = with_time ? minute : 0;
				t.tm_sec = with_time ? (int)sec : 0;
				return mktime(&t);
			}

			operator double() const {
				return (double)time_t(*this) + sec - (int)sec;
			}

		};

	}
}
