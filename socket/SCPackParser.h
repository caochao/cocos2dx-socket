#ifndef SC_PACKPARSER_H
#define SC_PACKPARSER_H

#include <map>
#include <vector>
#include "netdataoperate.h"
#include "tolua_fix.h"
#include "LuaBasicConversions.h"

namespace simplecreator {

	enum PackFieldType
	{
		UnKnowType = -1,
		UByteType,
		UInt16Type,
		Int32Type,
		StringType,
		NetDataType,
		PackType,
		Int16Type,
		FloatType,
		DoubleType,
		Int64Type,
	};

	struct PackFieldDefine
	{
		std::string FieldName;
		PackFieldType FieldType;

		bool IsArray;
		int ArrayCount;

		bool IsDymicCount;
		std::string CountFieldName;
	};

	struct PackStuctDefine
	{
		int PackHead;
		bool IsDymicPack;
		std::vector<PackFieldDefine*> PackField;

		int ListFieldCount;
		int SingleFieldCount;

		bool HasInit;
	};

	class PackObject;

	union NormalPackFieldValue
	{
		Int64	LongValue;  
		int	IntValue;  
		float FloatValue;
		double DoubleValue;
		PackObject* PackValue;     
		CNetData* NetDataValue;   
	}; 

	struct PackFieldValue
	{
		std::string FieldName;
		PackFieldType FieldType;
		NormalPackFieldValue	NormalValue;  
		std::string	StringValue;   
	};  
	struct PackFieldValueList
	{
		std::string FieldName;
		std::vector<PackFieldValue>* ValueList;
	};

	class LuaPackObject;
	class PackObject 
	{
	public:
		PackObject(int iPackHead, PackStuctDefine* pPackDefine);
		~PackObject();

		int GetPackHead();
		PackStuctDefine* GetPackStuctDefine();

		void SetPackBufferLength(int iPackBufferLength);
		int GetPackBufferLength();

		bool SetFieldValue(std::string sFieldName, int iFieldIndex, int iValue);
		bool SetFieldValue(std::string sFieldName, int iFieldIndex, Int64 iValue);
		bool SetFieldValue(std::string sFieldName, int iFieldIndex, float fValue);
		bool SetFieldValue(std::string sFieldName, int iFieldIndex, double fValue);
		bool SetFieldValue(std::string sFieldName, int iFieldIndex, std::string sValue);
		bool SetFieldValue(std::string sFieldName, int iFieldIndex, PackObject* pValue);
		bool SetFieldValue(std::string sFieldName, int iFieldIndex, CNetData* pValue);

		int GetIntFieldValue(std::string sFieldName);
		Int64 GetLongFieldValue(std::string sFieldName);
		float GetFloatFieldValue(std::string sFieldName);
		double GetDoubleFieldValue(std::string sFieldName);
		std::string GetStringFieldValue(std::string sFieldName);
		PackObject* GetPackFieldValue(std::string sFieldName);
		CNetData* GetNetDataFieldValue(std::string sFieldName);

		bool InitFieldValueToList(std::string sFieldName, int iFieldIndex, int iArrayCount);
		bool AddFieldValueToList(std::string sFieldName, int iFieldIndex, int iValueIndex, int iValue);
		bool AddFieldValueToList(std::string sFieldName, int iFieldIndex, int iValueIndex, Int64 iValue);
		bool AddFieldValueToList(std::string sFieldName, int iFieldIndex, int iValueIndex, float fValue);
		bool AddFieldValueToList(std::string sFieldName, int iFieldIndex, int iValueIndex, double fValue);
		bool AddFieldValueToList(std::string sFieldName, int iFieldIndex, int iValueIndex, PackObject* pValue);

		std::vector<int> GetIntFieldValueList(std::string sFieldName);
		std::vector<Int64> GetLongFieldValueList(std::string sFieldName);
		std::vector<float> GetFloatFieldValueList(std::string sFieldName);
		std::vector<double> GetDoubleFieldValueList(std::string sFieldName);
		std::vector<PackObject*> GetPackFieldValueList(std::string sFieldName);

		LuaPackObject* GetLuaPackObject(bool bTranArray=false);

		int GetIntFieldValueByIndex(int iFieldIndex);
		Int64 GetLongFieldValueByIndex(int iFieldIndex);
		float GetFloatFieldValueByIndex(int iFieldIndex);
		double GetDoubleFieldValueByIndex(int iFieldIndex);
		std::string GetStringFieldValueByIndex(int iFieldIndex);
		PackObject* GetPackFieldValueByIndex(int iFieldIndex);
		CNetData* GetNetDataFieldValueByIndex(int iFieldIndex);

		std::vector<int> GetIntFieldValueListByIndex(int iFieldIndex);
		std::vector<Int64> GetLongFieldValueListByIndex(int iFieldIndex);
		std::vector<float> GetFloatFieldValueListByIndex(int iFieldIndex);
		std::vector<double> GetDoubleFieldValueListByIndex(int iFieldIndex);
		std::vector<PackObject*> GetPackFieldValueListByIndex(int iFieldIndex);

		PackFieldValue* GetFieldByReadIndex(int iFieldIndex);
		PackFieldValueList* GetListFieldByReadIndex(int iFieldIndex);
	private:
		void ClearPackFieldValue(PackFieldValue* pFieldValue);
		PackFieldValue* GetField(std::string sFieldName, bool bNeedCreate=false);
		PackFieldValueList* GetListField(std::string sFieldName, bool bNeedCreate=false);

		PackFieldValue* GetFieldByIndex(std::string sFieldName, int iFieldIndex, bool bNeedCreate=false);
		PackFieldValueList* GetListFieldByIndex(std::string sFieldName, int iFieldIndex, bool bNeedCreate=false);

		int m_iSingleFieldCount;
		int m_iListFieldCount;

		std::vector<PackFieldValue*>* m_lFieldArray;
		std::vector<PackFieldValueList*>* m_lFieldListArray;

		int m_iPackHead;
		PackStuctDefine* m_pPackDefine;
		int m_iPackBufferLength;

		LuaPackObject* m_pLuaPackObj;
	};

	class LuaPackObject
	{
	public:
		LuaPackObject(PackObject* pPackObj, bool bTranArray=false);
		~LuaPackObject();

		void SetTranArray(bool bTranArray=true);
		void tolua(lua_State* tolua_S);
		void tolua_field(lua_State* tolua_S, PackFieldDefine* pFieldDefine, bool bArray, int iReadIndex);

	private:
		PackObject* m_pCppPackObj;
		bool m_bTranArray;
	};



	class PackParser
	{
	public:
		// 设置解析模块(是否64位封包)
		static void InitParseMode(bool bServer64);

		// 解析封包
		static PackObject* Parse(int iPackHead, CNetData* pData, int& iParsePos);

		// 转换cpp封包成lua信息
		static void ConvertPackObjectToLua(lua_State* tolua_S, LuaPackObject* pPackObj);

		// 清理封包
		static void ClearPackObject(PackObject* pPackObj);

		// 注册封包定义
		static bool StartPackDefine(int iPackHead, bool bDymicPack);
		static bool AddPackFieldDefine(int iPackHead, std::string sFieldName, PackFieldType iFieldType); 
		static bool AddPackFieldDefine(int iPackHead, std::string sFieldName, PackFieldType iFieldType, int iFieldCount);
		static bool AddPackFieldDefineDymic(int iPackHead, std::string sFieldName, PackFieldType iFieldType, const char* sCountFieldName);
		static bool StopPackDefine(int iPackHead);

		// 清理封包定义
		static bool ClearPackDefine(int iPackHead);

		// 查询是否存在指定字段
		static bool HasPackFieldDefine(int iPackHead, std::string sFieldName);
		// 获取指定字段类型
		static PackFieldType GetPackFieldDefineType(int iPackHead, std::string sFieldName);

		// 获取指定类型数据长度
		static int GetBufferLength(PackFieldType iFieldType);
		static int GetBufferLength(PackFieldType iFieldType, int iArrayCount);

	private:
		// 读取字段
		static bool ParseField(PackObject* pPackObj, PackFieldDefine* pFieldDefine, int iFieldIndex, CNetData* pData, int& iParsePos);

		static std::map<int, PackStuctDefine*> s_dPackDefineMap;
			
		static bool s_bServer64;
	};

}

#endif