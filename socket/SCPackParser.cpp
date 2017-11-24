#include "SCPackParser.h"
#include "base/CCConsole.h"

using namespace simplecreator;

bool PackParser::s_bServer64 = false;
std::map<int, PackStuctDefine*> PackParser::s_dPackDefineMap;

void simplecreator::PackParser::InitParseMode(bool bServer64)
{
	s_bServer64 = bServer64;
}

bool simplecreator::PackParser::StartPackDefine(int iPackHead, bool bDymicPack)
{
	auto pIter = s_dPackDefineMap.find(iPackHead);
	if (pIter != s_dPackDefineMap.end())
	{
		CCLOGERROR("StartPackDefine[0x%04X] fail, has repeat", iPackHead);
		return false;
	}
	PackStuctDefine* pPackDefine = new (std::nothrow) PackStuctDefine();
	if (pPackDefine == nullptr)
	{
		CCLOGERROR("StartPackDefine[0x%04X] fail, create PackStuctDefine error", iPackHead);
		return false;
	}
	pPackDefine->HasInit = false;
	pPackDefine->PackHead = iPackHead;
	pPackDefine->IsDymicPack = bDymicPack;
	pPackDefine->ListFieldCount = 0;

	s_dPackDefineMap[iPackHead] = pPackDefine;
	return true;
}

bool simplecreator::PackParser::ClearPackDefine(int iPackHead)
{
	auto pIter = s_dPackDefineMap.find(iPackHead);
	if (pIter == s_dPackDefineMap.end())
	{
		CCLOGERROR("ClearPackDefine[0x%04X] fail, no found", iPackHead);
		return false;
	}
	// 遍历字段
	for (auto pFieldIter = pIter->second->PackField.begin(); pFieldIter != pIter->second->PackField.end(); pFieldIter++)
	{
		PackFieldDefine* pFieldDefine = *pFieldIter;
		delete pFieldDefine;
	}
	pIter->second->PackField.clear();

	delete pIter->second;
	s_dPackDefineMap.erase(pIter);
	return true;
}

bool simplecreator::PackParser::AddPackFieldDefine(int iPackHead, std::string sFieldName, PackFieldType iFieldType)
{
	auto pIter = s_dPackDefineMap.find(iPackHead);
	if (pIter == s_dPackDefineMap.end())
	{
		CCLOGERROR("AddPackFieldDefine[0x%04X, %s] fail, no start", iPackHead, sFieldName.c_str());
		return false;
	}
	PackStuctDefine* pPackDefine = s_dPackDefineMap[iPackHead];
	PackFieldDefine* pFieldDefine = new (std::nothrow) PackFieldDefine();
	if (pFieldDefine == nullptr)
	{
		CCLOGERROR("StartPackDefine[0x%04X] fail, create PackFieldDefine error", iPackHead);
		return false;
	}

	pPackDefine->PackField.push_back(pFieldDefine);

	pFieldDefine->FieldName = sFieldName;
	pFieldDefine->FieldType = iFieldType;
	pFieldDefine->IsArray = false;
	pFieldDefine->IsDymicCount = false;
	return true;
}

bool simplecreator::PackParser::AddPackFieldDefine(int iPackHead, std::string sFieldName, PackFieldType iFieldType, int iFieldCount)
{
	if (!AddPackFieldDefine(iPackHead, sFieldName, iFieldType)) return false;

	PackStuctDefine* pPackDefine = s_dPackDefineMap[iPackHead];
	PackFieldDefine* pFieldDefine = pPackDefine->PackField.back();
	pFieldDefine->IsArray = true;
	pFieldDefine->ArrayCount = iFieldCount;

	if (iFieldType != PackFieldType::StringType && iFieldType != PackFieldType::NetDataType)
	{
		pPackDefine->ListFieldCount += 1;
	}
	return true;
}

bool simplecreator::PackParser::AddPackFieldDefineDymic(int iPackHead, std::string sFieldName, PackFieldType iFieldType, const char* sCountFieldName)
{
	if (!AddPackFieldDefine(iPackHead, sFieldName, iFieldType)) return false;
	PackStuctDefine* pPackDefine = s_dPackDefineMap[iPackHead];

	// 不是动态包,不允许有动态字段
	if (!pPackDefine->IsDymicPack)
	{
		CCLOGERROR("AddPackFieldDefine[0x%04X, %s, %s] fail, no dymic pack add dymic field", 
			iPackHead, sFieldName.c_str(), sCountFieldName);
		return false;
	}

	PackFieldDefine* pFieldDefine = pPackDefine->PackField.back();
	pFieldDefine->IsDymicCount = true;
	pFieldDefine->CountFieldName = sCountFieldName;

	if (iFieldType != PackFieldType::StringType && iFieldType != PackFieldType::NetDataType)
	{
		pPackDefine->ListFieldCount += 1;
	}
	return true;
}

bool simplecreator::PackParser::StopPackDefine(int iPackHead)
{
	auto pIter = s_dPackDefineMap.find(iPackHead);
	if (pIter == s_dPackDefineMap.end())
	{
		CCLOGERROR("StopPackDefine[0x%04X] fail, no start", iPackHead);
		return false;
	}
	PackStuctDefine* pPackDefine = s_dPackDefineMap[iPackHead];

	if (pPackDefine->HasInit)
	{
		CCLOGERROR("StopPackDefine[0x%04X] fail, has stop", iPackHead);
		return false;
	}

	// 校验是否有异常字段
	if (pPackDefine->IsDymicPack)
	{
		// 遍历字段
		for (auto pFieldIter = pPackDefine->PackField.begin(); pFieldIter != pPackDefine->PackField.end(); pFieldIter++)
		{
			PackFieldDefine* pFieldDefine = *pFieldIter;
			if (!pFieldDefine->IsDymicCount)continue;

			// 数量字段不存在
			std::string sCountFieldName = pFieldDefine->CountFieldName;
			if (!HasPackFieldDefine(iPackHead, sCountFieldName))
			{
				CCLOGERROR("StopPackDefine[0x%04X] fail,dymicField %s need countField = %s", iPackHead, 
					pFieldDefine->FieldName.c_str(), sCountFieldName.c_str());
				return false;
			}
			// 数量字段类型异常
			PackFieldType iFieldType = GetPackFieldDefineType(iPackHead, sCountFieldName);
			switch(iFieldType)
			{
			case PackFieldType::UByteType:
			case PackFieldType::UInt16Type:
			case PackFieldType::Int16Type:
			case PackFieldType::Int32Type:
				break;
			default:
				CCLOGERROR("StopPackDefine[0x%04X] fail,dymicField %s need countField = %s type eror=%d", iPackHead, 
					pFieldDefine->FieldName.c_str(), sCountFieldName.c_str(), iFieldType);
				return false;
			}
		}

	}

	pPackDefine->SingleFieldCount = pPackDefine->PackField.size() - pPackDefine->ListFieldCount;

	pPackDefine->HasInit = true;
	return true;
}


int simplecreator::PackParser::GetBufferLength(PackFieldType iFieldType)
{
	switch (iFieldType)
	{
	case PackFieldType::UByteType:
		return sizeof(unsigned char);
	case PackFieldType::UInt16Type:
		return sizeof(unsigned short);
	case PackFieldType::Int16Type:
		return sizeof(short);
	case PackFieldType::Int32Type:
		return sizeof(int);
	case PackFieldType::Int64Type:
		return sizeof(Int64);
	case PackFieldType::FloatType:
		return sizeof(float);
	case PackFieldType::DoubleType:
		return sizeof(double);
	// 未指定长度时，字符串流无内容
	case PackFieldType::StringType:
	case PackFieldType::NetDataType:
	// 封包对象此处无法计算长度，后续解析再检查
	case PackFieldType::PackType:
	default:
		break;
	}
	return 0;
}

int simplecreator::PackParser::GetBufferLength(PackFieldType iFieldType, int iArrayCount)
{
	// 字符串流长度,直接等于数组数量
	if (PackFieldType::StringType == iFieldType || PackFieldType::NetDataType == iFieldType)
	{
		return iArrayCount;
	}
	return GetBufferLength(iFieldType) * iArrayCount;
}

bool simplecreator::PackParser::HasPackFieldDefine(int iPackHead, std::string sFieldName)
{
	auto pIter = s_dPackDefineMap.find(iPackHead);
	if (pIter == s_dPackDefineMap.end())
	{
		CCLOGERROR("HasPackFieldDefine[0x%04X, %s] fail, no found pack", iPackHead, sFieldName.c_str());
		return false;
	}
	PackStuctDefine* pPackDefine = s_dPackDefineMap[iPackHead];
	
	for (auto pFieldIter = pPackDefine->PackField.begin(); pFieldIter != pPackDefine->PackField.end(); pFieldIter ++)
	{
		PackFieldDefine* pFieldDefine = *pFieldIter;
		if (pFieldDefine->FieldName == sFieldName)
		{
			return true;
		}
	}
	return false;
}

simplecreator::PackFieldType simplecreator::PackParser::GetPackFieldDefineType(int iPackHead, std::string sFieldName)
{
	auto pIter = s_dPackDefineMap.find(iPackHead);
	if (pIter == s_dPackDefineMap.end())
	{
		CCLOGERROR("GetPackFieldDefineType[0x%04X, %s] fail, no found pack", iPackHead, sFieldName.c_str());
		return PackFieldType::UnKnowType;
	}
	PackStuctDefine* pPackDefine = s_dPackDefineMap[iPackHead];

	for (auto pFieldIter = pPackDefine->PackField.begin(); pFieldIter != pPackDefine->PackField.end(); pFieldIter ++)
	{
		PackFieldDefine* pFieldDefine = *pFieldIter;
		if (pFieldDefine->FieldName == sFieldName)
		{
			return pFieldDefine->FieldType;
		}
	}
	CCLOGERROR("GetPackFieldDefineType[0x%04X, %s] fail, no found field", iPackHead, sFieldName.c_str());
	return PackFieldType::UnKnowType;
}


PackObject* simplecreator::PackParser::Parse(int iPackHead, CNetData* pData, int& iParsePos)
{
	auto pIter = s_dPackDefineMap.find(iPackHead);
	if (pIter == s_dPackDefineMap.end())
	{
		CCLOGERROR("Parse[0x%04X] fail, no found define", iPackHead);
		return nullptr;
	}
	PackStuctDefine* pPackDefine = s_dPackDefineMap[iPackHead];
	if (!pPackDefine->HasInit)
	{
		CCLOGERROR("Parse[0x%04X] fail, PackStuctDefine not init end", iPackHead);
		return nullptr;
	}

	PackObject* pPackObj = new (std::nothrow) PackObject(iPackHead, pPackDefine);
	if (pPackObj == nullptr)
	{
		CCLOGERROR("Parse[0x%04X] fail, create PackObject error", iPackHead);
		return nullptr;
	}

	int iStartPos = iParsePos;

	int iSingleFieldIndex = -1;
	int iListFieldIndex = -1;

	// 解析固定包部分
	for (auto pFieldIter = pPackDefine->PackField.begin(); pFieldIter != pPackDefine->PackField.end(); pFieldIter++)
	{
		PackFieldDefine* pFieldDefine = *pFieldIter;

		// 动态长度的情况下
		if (pFieldDefine->IsDymicCount)
		{
			// 去除指针占位符
			pData->ReadINT32(iStartPos);
			// 如果是64位封包，需要再去除次
			if (s_bServer64)
			{
				pData->ReadINT32(iStartPos);
			}
			// 字符串流使用 单个数据索引,需要累加
			if (pFieldDefine->FieldType == PackFieldType::StringType || pFieldDefine->FieldType == PackFieldType::NetDataType)
			{
				iSingleFieldIndex++;
			}
			continue;
		}

		int iReadIndex = -1;
		if (pFieldDefine->IsArray && pFieldDefine->FieldType != PackFieldType::StringType && pFieldDefine->FieldType != PackFieldType::NetDataType)
		{
			iListFieldIndex++;
			iReadIndex = iListFieldIndex;
		}
		else
		{
			iSingleFieldIndex++;
			iReadIndex = iSingleFieldIndex;
		}

		// 解析一个个字段
		if (!ParseField(pPackObj, pFieldDefine, iReadIndex, pData, iStartPos))
		{
			delete pPackObj;
			CCLOGERROR("Parse[0x%04X, %d] NormalField[%s] fail", iPackHead, iParsePos, pFieldDefine->FieldName.c_str());
			return nullptr;
		}
	}

	iSingleFieldIndex = -1;
	iListFieldIndex = -1;

	// 解析动态包部分
	for (auto pFieldIter = pPackDefine->PackField.begin(); pFieldIter != pPackDefine->PackField.end(); pFieldIter++)
	{
		PackFieldDefine* pFieldDefine = *pFieldIter;

		// 不是动态长度的跳过
		if (!pFieldDefine->IsDymicCount)
		{
			iSingleFieldIndex++;
			continue;
		}
		int iFieldIndex = 0;
		// 字符串流使用 单个数据索引,需要累加
		if (pFieldDefine->FieldType == PackFieldType::StringType || pFieldDefine->FieldType == PackFieldType::NetDataType)
		{
			iSingleFieldIndex++;
			iFieldIndex = iSingleFieldIndex;
		}else{
			iListFieldIndex++;
			iFieldIndex = iListFieldIndex;
		}

		// 解析一个个字段
		if (!ParseField(pPackObj, pFieldDefine, iFieldIndex, pData, iStartPos))
		{
			delete pPackObj;
			CCLOGERROR("Parse[0x%04X, %d] DymicField[%s] fail", iPackHead, iParsePos, pFieldDefine->FieldName.c_str());
			return nullptr;
		}
	}

	int iPackBufferLength = iStartPos - iParsePos;
	pPackObj->SetPackBufferLength(iPackBufferLength);

	iParsePos = iStartPos;
	return pPackObj;
}

bool simplecreator::PackParser::ParseField(PackObject* pPackObj, PackFieldDefine* pFieldDefine, int iFieldIndex, CNetData* pData, int& iParsePos)
{

	// 数组及数量
	bool bArray = false;
	int iArrayCount = 0;
	if (pFieldDefine->IsArray)
	{
		bArray = true;
		iArrayCount = pFieldDefine->ArrayCount;
	}
	else if (pFieldDefine->IsDymicCount)
	{
		bArray = true;
		iArrayCount = pPackObj->GetIntFieldValue(pFieldDefine->CountFieldName);
	}

	/*
	if (iParsePos >= pData->GetLength())
	{
		CCLOGERROR("ParseField[0x%04X] Field[%s] fail, buff len[%d] <= pos[%d]", pPackObj->GetPackHead(), 
			pFieldDefine->FieldName.c_str(), pData->GetLength(), iParsePos);
		return false;
	}
	*/

	// 检测最小需求封包流长度(无法检查动态封包对象的情况)
	int iMinNeedPos = iParsePos;
	if (bArray)
	{
		iMinNeedPos += GetBufferLength(pFieldDefine->FieldType, iArrayCount);
	}
	else
	{
		iMinNeedPos += GetBufferLength(pFieldDefine->FieldType);
	}
	// 长度不足异常
	if (iMinNeedPos > pData->GetLength())
	{
		CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, buff len[%d] <= min need pos[%d]", pPackObj->GetPackHead(), iParsePos,
					pFieldDefine->FieldName.c_str(), pData->GetLength(), iMinNeedPos);
		return false;
	}


	// 初始化数组
	if (bArray)
	{
		// 字符串流,不初始化数组
		if (PackFieldType::StringType != pFieldDefine->FieldType && PackFieldType::NetDataType != pFieldDefine->FieldType)
		{
			if (!pPackObj->InitFieldValueToList(pFieldDefine->FieldName, iFieldIndex, iArrayCount))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, InitFieldValueToList error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
		}

		// 数组是空的不需要后续解析
		if (iArrayCount <= 0)
		{
			// 如果流空的, 给个空流
			if (PackFieldType::StringType == pFieldDefine->FieldType)
			{
				if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, ""))
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set empty str error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str());
					return false;
				}
			}
			else if (PackFieldType::NetDataType == pFieldDefine->FieldType)
			{
				CNetData* pNewData = new (std::nothrow) CNetData();
				if (pNewData == nullptr)
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, create CNetData error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str());
					return false;
				}
				if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, pNewData))
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set empty CNetData error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str());
					return false;
				}
			}
			return true;
		}
	}

	// 读取字段
	switch (pFieldDefine->FieldType)
	{
	case  PackFieldType::UByteType:
		if (bArray)
		{
			for (int iIndex = 0; iIndex < iArrayCount; iIndex++)
			{
				int iValue = pData->ReadUBYTE(iParsePos);
				if (!pPackObj->AddFieldValueToList(pFieldDefine->FieldName, iFieldIndex, iIndex, iValue))
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, AddFieldValueToList UBYTE error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str());
					return false;
				}
			}
		}
		else
		{
			int iValue = pData->ReadUBYTE(iParsePos);
			if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, iValue))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set UBYTE error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
		}
		break;

	case  PackFieldType::UInt16Type:
		if (bArray)
		{
			for (int iIndex = 0; iIndex < iArrayCount; iIndex++)
			{
				int iValue = pData->ReadUINT16(iParsePos);
				if (!pPackObj->AddFieldValueToList(pFieldDefine->FieldName, iFieldIndex, iIndex, iValue))
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, AddFieldValueToList UINT16 error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str());
					return false;
				}
			}
		}
		else
		{
			int iValue = pData->ReadUINT16(iParsePos);
			if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, iValue))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set UINT16 error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
		}
		break;

	case  PackFieldType::Int16Type:
		if (bArray)
		{
			for (int iIndex = 0; iIndex < iArrayCount; iIndex++)
			{
				int iValue = pData->ReadINT16(iParsePos);
				if (!pPackObj->AddFieldValueToList(pFieldDefine->FieldName, iFieldIndex, iIndex, iValue))
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, AddFieldValueToList INT16 error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str());
					return false;
				}
			}
		}
		else
		{
			int iValue = pData->ReadINT16(iParsePos);
			if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, iValue))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set INT16 error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
		}
		break;

	case  PackFieldType::Int32Type:
		if (bArray)
		{
			for (int iIndex = 0; iIndex < iArrayCount; iIndex++)
			{
				int iValue = pData->ReadINT32(iParsePos);
				if (!pPackObj->AddFieldValueToList(pFieldDefine->FieldName, iFieldIndex, iIndex, iValue))
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, AddFieldValueToList INT32 error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str());
					return false;
				}
			}
		}
		else
		{
			int iValue = pData->ReadINT32(iParsePos);
			if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, iValue))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set INT32 error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
		}
		break;

	case  PackFieldType::Int64Type:
		if (bArray)
		{
			for (int iIndex = 0; iIndex < iArrayCount; iIndex++)
			{
				Int64 iValue = pData->ReadINT64(iParsePos);
				if (!pPackObj->AddFieldValueToList(pFieldDefine->FieldName, iFieldIndex, iIndex, iValue))
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, AddFieldValueToList INT64 error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str());
					return false;
				}
			}
		}
		else
		{
			Int64 iValue = pData->ReadINT64(iParsePos);
			if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, iValue))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set INT64 error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
		}
		break;

	case  PackFieldType::FloatType:
		if (bArray)
		{
			for (int iIndex = 0; iIndex < iArrayCount; iIndex++)
			{
				float fValue = pData->ReadFloat(iParsePos);
				if (!pPackObj->AddFieldValueToList(pFieldDefine->FieldName, iFieldIndex, iIndex, fValue))
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, AddFieldValueToList float error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str());
					return false;
				}
			}
		}
		else
		{
			float fValue = pData->ReadFloat(iParsePos);
			if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, fValue))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set float error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
		}
		break;

	case  PackFieldType::DoubleType:
		if (bArray)
		{
			for (int iIndex = 0; iIndex < iArrayCount; iIndex++)
			{
				double fValue = pData->ReadDouble(iParsePos);
				if (!pPackObj->AddFieldValueToList(pFieldDefine->FieldName, iFieldIndex, iIndex, fValue))
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, AddFieldValueToList double error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str());
					return false;
				}
			}
		}
		else
		{
			double fValue = pData->ReadDouble(iParsePos);
			if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, fValue))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set double error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
		}
		break;

	case  PackFieldType::StringType:
		{
			std::string sValue = pData->ReadString(iArrayCount, iParsePos);
			if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, sValue))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set str error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
			break;
		}

	case  PackFieldType::NetDataType:
		{
			CNetData* pNewData = new (std::nothrow) CNetData();
			if (pNewData == nullptr)
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, create CNetData error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
			pNewData->AddObj(pData, iParsePos, iArrayCount);
			iParsePos += iArrayCount;
			if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, pNewData))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set CNetData error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
			break;
		}

	case  PackFieldType::PackType:
		if (bArray)
		{
			for (int iIndex = 0; iIndex < iArrayCount; iIndex++)
			{
				// 封包解析需要检测长度
				if ((int)(iParsePos + sizeof(unsigned short)) >= pData->GetLength())
				{
					CCLOGERROR("ParseField[0x%04X] Field[%s] parse pack[%d] head fail, len=%d pos=%d", pPackObj->GetPackHead(), 
						pFieldDefine->FieldName.c_str(), iIndex, pData->GetLength(), iParsePos);
					return false;
				}
				int iPackHead = pData->ReadUINT16(iParsePos);
				PackObject* pNewPack = Parse(iPackHead, pData, iParsePos);
				if (pNewPack == nullptr)
				{
					CCLOGERROR("ParseField[0x%04X] Field[%s] parse body[%d] fail, len=%d pos=%d", pPackObj->GetPackHead(), 
						pFieldDefine->FieldName.c_str(), iIndex, pData->GetLength(), iParsePos);
					return false;
				}

				if (!pPackObj->AddFieldValueToList(pFieldDefine->FieldName, iFieldIndex, iIndex, pNewPack))
				{
					CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, AddFieldValueToList[%d] error", pPackObj->GetPackHead(), iParsePos, 
						pFieldDefine->FieldName.c_str(), iIndex);
					return false;
				}
			}
		}
		else
		{
			// 封包解析需要检测长度
			if ((int)(iParsePos + sizeof(unsigned short)) >= pData->GetLength())
			{
				CCLOGERROR("ParseField[0x%04X] Field[%s] parse head fail, len=%d pos=%d", pPackObj->GetPackHead(), 
					pFieldDefine->FieldName.c_str(), pData->GetLength(), iParsePos);
				return false;
			}
			int iPackHead = pData->ReadUINT16(iParsePos);
			PackObject* pNewPack = Parse(iPackHead, pData, iParsePos);
			if (pNewPack == nullptr)
			{
				CCLOGERROR("ParseField[0x%04X] Field[%s] parse body fail, len=%d pos=%d", pPackObj->GetPackHead(), 
					pFieldDefine->FieldName.c_str(), pData->GetLength(), iParsePos);
				return false;
			}
			if (!pPackObj->SetFieldValue(pFieldDefine->FieldName, iFieldIndex, pNewPack))
			{
				CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, set PackObject error", pPackObj->GetPackHead(), iParsePos, 
					pFieldDefine->FieldName.c_str());
				return false;
			}
		}
		break;
	default:
		CCLOGERROR("ParseField[0x%04X, %d] Field[%s] fail, unknow=%d", pPackObj->GetPackHead(), iParsePos, 
			pFieldDefine->FieldName.c_str(), pFieldDefine->FieldType);
		return false;
		break;
	}

	if (iParsePos < iMinNeedPos )
	{
		CCLOGERROR("ParseField[0x%04X] Field[%s][type:%d] warn, parsePos[%d] < minNeedPos[%d]", pPackObj->GetPackHead(), 
			pFieldDefine->FieldName.c_str(), pFieldDefine->FieldType, iParsePos, iMinNeedPos);
		return false;
	}

	return true;
}

void simplecreator::PackParser::ClearPackObject(PackObject* pPackObj)
{
	if (pPackObj != nullptr)
	{
		delete pPackObj;
	}
}

// 转换cpp封包成lua信息
void simplecreator::PackParser::ConvertPackObjectToLua(lua_State* tolua_S, LuaPackObject* pPackObj)
{
	pPackObj->tolua(tolua_S);
}


simplecreator::LuaPackObject::LuaPackObject(PackObject* pPackObj, bool bTranArray)
{
	m_pCppPackObj = pPackObj;
	m_bTranArray = bTranArray;
}

simplecreator::LuaPackObject::~LuaPackObject()
{
	m_pCppPackObj = nullptr;
}

void simplecreator::LuaPackObject::SetTranArray(bool bTranArray)
{
	m_bTranArray = bTranArray;
}

void simplecreator::LuaPackObject::tolua(lua_State* tolua_S)
{
    if (nullptr == tolua_S)
        return;

    PackStuctDefine* pPackDefine = m_pCppPackObj->GetPackStuctDefine();

    lua_newtable(tolua_S);

	int iSingleFieldIndex = 0;
	int iListFieldIndex = 0;

	int iAllFieldIndex = 0;
	for (auto pFieldIter = pPackDefine->PackField.begin(); pFieldIter != pPackDefine->PackField.end(); pFieldIter++)
	{
		PackFieldDefine* pFieldDefine = *pFieldIter;
		if (m_bTranArray){
			lua_pushnumber(tolua_S, (lua_Number)++iAllFieldIndex);
		}else{
			lua_pushstring(tolua_S, pFieldDefine->FieldName.c_str());
		}

		bool bArray = (pFieldDefine->IsArray || pFieldDefine->IsDymicCount) && (
			PackFieldType::StringType != pFieldDefine->FieldType && PackFieldType::NetDataType != pFieldDefine->FieldType);
		if (bArray){
			tolua_field(tolua_S, pFieldDefine, bArray, iListFieldIndex++);
		}else{
			tolua_field(tolua_S, pFieldDefine, bArray, iSingleFieldIndex++);
		}


        lua_rawset(tolua_S, -3);
	}
}


void simplecreator::LuaPackObject::tolua_field(lua_State* tolua_S, PackFieldDefine* pFieldDefine, bool bArray, int iReadIndex)
{
    if (nullptr == tolua_S)
        return;

    if (bArray)
	{
    	lua_newtable(tolua_S);
    }

	switch (pFieldDefine->FieldType)
	{
	case PackFieldType::UByteType:
	case PackFieldType::UInt16Type:
	case PackFieldType::Int16Type:
	case PackFieldType::Int32Type:
		if (bArray){
			PackFieldValueList* pListFieldValue = m_pCppPackObj->GetListFieldByReadIndex(iReadIndex);
			if (pListFieldValue != nullptr){
				std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
				int iIndex = 1;
				for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
				{
					lua_pushnumber(tolua_S, (lua_Number)iIndex++);
					lua_pushnumber(tolua_S, pListIter->NormalValue.IntValue);
					lua_rawset(tolua_S, -3);
				}
			}else{
				CCLOGERROR("tolua_field[0x%04X, %s] GetListFieldByReadIndex fail, no found field", m_pCppPackObj->GetPackHead(), iReadIndex);
			}
		}else{
    		lua_pushnumber(tolua_S, m_pCppPackObj->GetIntFieldValueByIndex(iReadIndex));
		}
		break;
	case PackFieldType::Int64Type:
		if (bArray){
			PackFieldValueList* pListFieldValue = m_pCppPackObj->GetListFieldByReadIndex(iReadIndex);
			if (pListFieldValue != nullptr){
				std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
				int iIndex = 1;
				for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
				{
					lua_pushnumber(tolua_S, (lua_Number)iIndex++);
					lua_pushnumber(tolua_S, pListIter->NormalValue.LongValue);
					lua_rawset(tolua_S, -3);
				}
			}else{
				CCLOGERROR("tolua_field[0x%04X, %s] GetListFieldByReadIndex fail, no found field", m_pCppPackObj->GetPackHead(), iReadIndex);
			}
		}else{
			lua_pushnumber(tolua_S, m_pCppPackObj->GetLongFieldValueByIndex(iReadIndex));
		}
		break;
	case PackFieldType::FloatType:
		if (bArray){
			PackFieldValueList* pListFieldValue = m_pCppPackObj->GetListFieldByReadIndex(iReadIndex);
			if (pListFieldValue != nullptr){
				std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
				int iIndex = 1;
				for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
				{
					lua_pushnumber(tolua_S, (lua_Number)iIndex++);
					lua_pushnumber(tolua_S, pListIter->NormalValue.FloatValue);
					lua_rawset(tolua_S, -3);
				}
			}else{
				CCLOGERROR("tolua_field[0x%04X, %s] GetListFieldByReadIndex fail, no found field", m_pCppPackObj->GetPackHead(), iReadIndex);
			}
		}else{
			lua_pushnumber(tolua_S, m_pCppPackObj->GetFloatFieldValueByIndex(iReadIndex));
		}
		break;
	case PackFieldType::DoubleType:
		if (bArray){
			PackFieldValueList* pListFieldValue = m_pCppPackObj->GetListFieldByReadIndex(iReadIndex);
			if (pListFieldValue != nullptr){
				std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
				int iIndex = 1;
				for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
				{
					lua_pushnumber(tolua_S, (lua_Number)iIndex++);
					lua_pushnumber(tolua_S, pListIter->NormalValue.DoubleValue);
					lua_rawset(tolua_S, -3);
				}
			}else{
				CCLOGERROR("tolua_field[0x%04X, %s] GetListFieldByReadIndex fail, no found field", m_pCppPackObj->GetPackHead(), iReadIndex);
			}
		}else{
			lua_pushnumber(tolua_S, m_pCppPackObj->GetDoubleFieldValueByIndex(iReadIndex));
		}
		break;
	case PackFieldType::StringType:
    	lua_pushstring(tolua_S, m_pCppPackObj->GetStringFieldValueByIndex(iReadIndex).c_str());
        break;
	case PackFieldType::NetDataType:
		{
			simplecreator::CNetData* pData = m_pCppPackObj->GetNetDataFieldValueByIndex(iReadIndex);
			if(pData == nullptr){
				lua_pushnil(tolua_S);
			}else{
				pData->AddRetain();
				pData->SetNoDelByClear();
				object_to_luaval<simplecreator::CNetData>(tolua_S, "sc.CNetData",(simplecreator::CNetData*)pData);
			}
		}
        break;
	case PackFieldType::PackType:
		if (bArray){
			PackFieldValueList* pListFieldValue = m_pCppPackObj->GetListFieldByReadIndex(iReadIndex);
			if (pListFieldValue != nullptr){
				std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
				int iIndex = 1;
				for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
				{
					PackObject* pSubPack = pListIter->NormalValue.PackValue;
					lua_pushnumber(tolua_S, (lua_Number)iIndex++);
					if(pSubPack == nullptr){
						lua_pushnil(tolua_S);
					}else{
						LuaPackObject* pLuaSubPack = pSubPack->GetLuaPackObject(m_bTranArray);
						pLuaSubPack->tolua(tolua_S);
					}
					lua_rawset(tolua_S, -3);
				}
			}else{
				CCLOGERROR("tolua_field[0x%04X, %s] GetListFieldByReadIndex fail, no found field", m_pCppPackObj->GetPackHead(), iReadIndex);
			}
		}else{
	    	PackObject* pSubPack = m_pCppPackObj->GetPackFieldValueByIndex(iReadIndex);
	    	if(pSubPack == nullptr){
	    		lua_pushnil(tolua_S);
			}else{
	    		LuaPackObject* pLuaSubPack = pSubPack->GetLuaPackObject(m_bTranArray);
	    		pLuaSubPack->tolua(tolua_S);
	    	}
		}
        break;
	default:
    	lua_pushnil(tolua_S);
		break;
	}
}

simplecreator::PackObject::PackObject(int iPackHead, PackStuctDefine* pPackDefine)
{
	m_iPackHead = iPackHead;
	m_pPackDefine = pPackDefine;

	m_iPackBufferLength = 0;
	m_lFieldArray = new std::vector<PackFieldValue*>(pPackDefine->SingleFieldCount, nullptr);
	m_lFieldListArray = new std::vector<PackFieldValueList*>(pPackDefine->ListFieldCount, nullptr);


	m_pLuaPackObj = nullptr;
}

simplecreator::PackObject::~PackObject()
{
	for (auto pIter = m_lFieldArray->begin(); pIter != m_lFieldArray->end(); pIter++)
	{
		if (*pIter == nullptr)
		{
			continue;
		}
		ClearPackFieldValue(*pIter);
		delete *pIter;
	}
	m_lFieldArray->clear();
	delete m_lFieldArray;
	m_lFieldArray = nullptr;


	for (auto pIter = m_lFieldListArray->begin(); pIter != m_lFieldListArray->end(); pIter++)
	{
		if (*pIter == nullptr)
		{
			continue;
		}
		std::vector<PackFieldValue>* pList = (*pIter)->ValueList;
		if (pList != nullptr)
		{
			for (auto pListIter = pList->begin(); pListIter != pList->end(); pListIter++)
			{
				ClearPackFieldValue(&(*pListIter));
			}
			delete pList;
		}
		delete *pIter;
	}
	m_lFieldListArray->clear();
	delete m_lFieldListArray;
	m_lFieldListArray = nullptr;


	if (m_pLuaPackObj != nullptr)
	{
		delete m_pLuaPackObj;
		m_pLuaPackObj = nullptr;
	}
}
LuaPackObject* simplecreator::PackObject::GetLuaPackObject(bool bTranArray)
{
	if(m_pLuaPackObj == nullptr)
	{
		m_pLuaPackObj = new LuaPackObject(this, bTranArray);
	}
	else
	{
		m_pLuaPackObj->SetTranArray(bTranArray);
	}
	return m_pLuaPackObj;
}

PackStuctDefine* simplecreator::PackObject::GetPackStuctDefine()
{
	return m_pPackDefine;
}

void simplecreator::PackObject::ClearPackFieldValue(PackFieldValue* pFieldValue)
{
	if (pFieldValue == nullptr)
	{
		return;
	}
	switch (pFieldValue->FieldType)
	{
	case PackFieldType::NetDataType:
		if (pFieldValue->NormalValue.NetDataValue)
		{
			//delete pFieldValue->NormalValue.NetDataValue;
			pFieldValue->NormalValue.NetDataValue->Clear();
			pFieldValue->NormalValue.NetDataValue = nullptr;
		}
		break;
	case PackFieldType::PackType:
		if (pFieldValue->NormalValue.PackValue)
		{
			delete pFieldValue->NormalValue.PackValue;
			pFieldValue->NormalValue.PackValue = nullptr;
		}
		break;
	default:
		break;
	}
}



int simplecreator::PackObject::GetPackHead()
{
	return m_iPackHead;
}


void simplecreator::PackObject::SetPackBufferLength(int iPackBufferLength)
{
	m_iPackBufferLength = iPackBufferLength;
}


int simplecreator::PackObject::GetPackBufferLength()
{
	return m_iPackBufferLength;
}



PackFieldValue* simplecreator::PackObject::GetField(std::string sFieldName, bool bNeedCreate)
{
	for (auto pIter = m_lFieldArray->begin(); pIter != m_lFieldArray->end(); pIter++)
	{
		if (*pIter == nullptr)
		{
			continue;
		}
		if ((*pIter)->FieldName == sFieldName)
		{
			return *pIter;
		}
	}
	if (!bNeedCreate)
	{
		return nullptr;
	}

	PackFieldValue* pFieldValue = new (std::nothrow) PackFieldValue();
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetListField[0x%04X, %s] fail, create PackFieldValue error", this->GetPackHead(), sFieldName.c_str());
		return nullptr;
	}
	pFieldValue->FieldName = sFieldName;
	m_lFieldArray->push_back(pFieldValue);
	return pFieldValue;
}

PackFieldValueList* simplecreator::PackObject::GetListField(std::string sFieldName, bool bNeedCreate)
{
	for (auto pIter = m_lFieldListArray->begin(); pIter != m_lFieldListArray->end(); pIter++)
	{
		if (*pIter == nullptr)
		{
			continue;
		}
		if ((*pIter)->FieldName == sFieldName)
		{
			return *pIter;
		}
	}
	if (!bNeedCreate)
	{
		return nullptr;
	}

	PackFieldValueList* pFieldValue = new (std::nothrow) PackFieldValueList();
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetListField[0x%04X, %s] fail, create PackFieldValueList error", this->GetPackHead(), sFieldName.c_str());
		return nullptr;
	}
	pFieldValue->FieldName = sFieldName;
	m_lFieldListArray->push_back(pFieldValue);
	return pFieldValue;
}


PackFieldValue* simplecreator::PackObject::GetFieldByIndex(std::string sFieldName, int iFieldIndex, bool bNeedCreate/*=false*/)
{
	if (iFieldIndex >= m_pPackDefine->SingleFieldCount)
	{
		CCLOGERROR("GetFieldByIndex[0x%04X, %s] fail, index[%d] >= count %d error", this->GetPackHead(), sFieldName.c_str(),
			iFieldIndex, m_pPackDefine->SingleFieldCount);
		return nullptr;
	}
	PackFieldValue* pFieldValue = (*m_lFieldArray)[iFieldIndex];
	if (pFieldValue == nullptr)
	{
		if (!bNeedCreate)
		{
			CCLOGERROR("GetFieldByIndex[0x%04X, %s] fail, index[%d] no create", this->GetPackHead(), sFieldName.c_str(),
				iFieldIndex);
			return nullptr;
		}
		pFieldValue = new (std::nothrow) PackFieldValue();
		if (pFieldValue == nullptr)
		{
			CCLOGERROR("GetFieldByIndex[0x%04X, %s] fail, create PackFieldValueList error", this->GetPackHead(), sFieldName.c_str());
			return nullptr;
		}

		pFieldValue->FieldName = sFieldName;
		(*m_lFieldArray)[iFieldIndex] = pFieldValue;
	}
	return pFieldValue;
}

PackFieldValue* simplecreator::PackObject::GetFieldByReadIndex(int iFieldIndex)
{
	if (iFieldIndex >= m_pPackDefine->SingleFieldCount)
	{
		CCLOGERROR("GetFieldByReadIndex[0x%04X] fail, index[%d] >= count %d error", this->GetPackHead(),
			iFieldIndex, m_pPackDefine->SingleFieldCount);
		return nullptr;
	}
	PackFieldValue* pFieldValue = (*m_lFieldArray)[iFieldIndex];
	return pFieldValue;
}

PackFieldValueList* simplecreator::PackObject::GetListFieldByReadIndex(int iFieldIndex)
{
	if (iFieldIndex >= m_pPackDefine->ListFieldCount)
	{
		CCLOGERROR("GetListFieldByReadIndex[0x%04X] fail, index[%d] >= count %d error", this->GetPackHead(),
			iFieldIndex, m_pPackDefine->ListFieldCount);
		return nullptr;
	}
	PackFieldValueList* pFieldValue = (*m_lFieldListArray)[iFieldIndex];
	return pFieldValue;
}

PackFieldValueList* simplecreator::PackObject::GetListFieldByIndex(std::string sFieldName, int iFieldIndex, bool bNeedCreate/*=false*/)
{
	if (iFieldIndex >= m_pPackDefine->ListFieldCount)
	{
		CCLOGERROR("GetListFieldByIndex[0x%04X, %s] fail, index[%d] >= count %d error", this->GetPackHead(), sFieldName.c_str(),
			iFieldIndex, m_pPackDefine->ListFieldCount);
		return nullptr;
	}
	PackFieldValueList* pFieldValue = (*m_lFieldListArray)[iFieldIndex];
	if (pFieldValue == nullptr)
	{
		if (!bNeedCreate)
		{
			CCLOGERROR("GetListFieldByIndex[0x%04X, %s] fail, index[%d] no create", this->GetPackHead(), sFieldName.c_str(),
				iFieldIndex);
			return nullptr;
		}
		pFieldValue = new (std::nothrow) PackFieldValueList();
		if (pFieldValue == nullptr)
		{
			CCLOGERROR("GetListFieldByIndex[0x%04X, %s] fail, create PackFieldValueList error", this->GetPackHead(), sFieldName.c_str());
			return nullptr;
		}

		pFieldValue->FieldName = sFieldName;
		(*m_lFieldListArray)[iFieldIndex] = pFieldValue;
	}
	return pFieldValue;
}

bool simplecreator::PackObject::SetFieldValue(std::string sFieldName, int iFieldIndex, int iValue)
{
	NormalPackFieldValue pNormalValue;
	pNormalValue.IntValue = iValue;

	PackFieldValue* pFieldValue = GetFieldByIndex(sFieldName, iFieldIndex, true);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("SetFieldValue[0x%04X, %s] fail, GetFieldByIndex[%d] error", this->GetPackHead(), sFieldName.c_str(), iFieldIndex);
		return false;
	}
	pFieldValue->FieldType = PackFieldType::Int32Type;
	pFieldValue->NormalValue = pNormalValue;
	return true;
}
bool simplecreator::PackObject::SetFieldValue(std::string sFieldName, int iFieldIndex, Int64 iValue)
{
	NormalPackFieldValue pNormalValue;
	pNormalValue.LongValue = iValue;

	PackFieldValue* pFieldValue = GetFieldByIndex(sFieldName, iFieldIndex, true);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("SetFieldValue[0x%04X, %s] fail, GetFieldByIndex[%d] error", this->GetPackHead(), sFieldName.c_str(), iFieldIndex);
		return false;
	}
	pFieldValue->FieldType = PackFieldType::Int64Type;
	pFieldValue->NormalValue = pNormalValue;
	return true;
}
bool simplecreator::PackObject::SetFieldValue(std::string sFieldName, int iFieldIndex, float fValue)
{
	NormalPackFieldValue pNormalValue;
	pNormalValue.FloatValue = fValue;

	PackFieldValue* pFieldValue = GetFieldByIndex(sFieldName, iFieldIndex, true);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("SetFieldValue[0x%04X, %s] fail, GetFieldByIndex[%d] error", this->GetPackHead(), sFieldName.c_str(), iFieldIndex);
		return false;
	}
	pFieldValue->FieldType = PackFieldType::FloatType;
	pFieldValue->NormalValue = pNormalValue;
	return true;
}

bool simplecreator::PackObject::SetFieldValue(std::string sFieldName, int iFieldIndex, double fValue)
{
	NormalPackFieldValue pNormalValue;
	pNormalValue.DoubleValue = fValue;

	PackFieldValue* pFieldValue = GetFieldByIndex(sFieldName, iFieldIndex, true);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("SetFieldValue[0x%04X, %s] fail, GetFieldByIndex[%d] error", this->GetPackHead(), sFieldName.c_str(), iFieldIndex);
		return false;
	}
	pFieldValue->FieldType = PackFieldType::DoubleType;
	pFieldValue->NormalValue = pNormalValue;
	return true;
}


bool simplecreator::PackObject::SetFieldValue(std::string sFieldName, int iFieldIndex, std::string sValue)
{
	PackFieldValue* pFieldValue = GetFieldByIndex(sFieldName, iFieldIndex, true);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("SetFieldValue[0x%04X, %s] fail, GetFieldByIndex[%d] error", this->GetPackHead(), sFieldName.c_str(), iFieldIndex);
		return false;
	}
	pFieldValue->FieldType = PackFieldType::StringType;
	pFieldValue->StringValue = sValue;
	return true;
}

bool simplecreator::PackObject::SetFieldValue(std::string sFieldName, int iFieldIndex, PackObject* pValue)
{

	PackFieldValue* pFieldValue = GetFieldByIndex(sFieldName, iFieldIndex, true);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("SetFieldValue[0x%04X, %s] fail, GetFieldByIndex[%d] error", this->GetPackHead(), sFieldName.c_str(), iFieldIndex);
		return false;
	}
	NormalPackFieldValue pNormalValue;
	pNormalValue.PackValue = pValue;

	pFieldValue->FieldType = PackFieldType::PackType;
	pFieldValue->NormalValue = pNormalValue;
	return true;
}

bool simplecreator::PackObject::SetFieldValue(std::string sFieldName, int iFieldIndex, CNetData* pValue)
{

	PackFieldValue* pFieldValue = GetFieldByIndex(sFieldName, iFieldIndex, true);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("SetFieldValue[0x%04X, %s] fail, GetFieldByIndex[%d] error", this->GetPackHead(), sFieldName.c_str(), iFieldIndex);
		return false;
	}
	NormalPackFieldValue pNormalValue;
	pNormalValue.NetDataValue = pValue;

	pFieldValue->FieldType = PackFieldType::NetDataType;
	pFieldValue->NormalValue = pNormalValue;
	return true;
}

int simplecreator::PackObject::GetIntFieldValue(std::string sFieldName)
{
	PackFieldValue* pFieldValue = GetField(sFieldName);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetIntFieldValue[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return 0;
	}
	if (pFieldValue->FieldType != PackFieldType::UByteType && pFieldValue->FieldType != PackFieldType::UInt16Type
		&& pFieldValue->FieldType != PackFieldType::Int32Type && pFieldValue->FieldType != PackFieldType::Int16Type)
	{
		CCLOGERROR("GetIntFieldValue[0x%04X, %s] fail, field type error = %d", this->GetPackHead(), sFieldName.c_str(), pFieldValue->FieldType);
		return 0;
	}
	return pFieldValue->NormalValue.IntValue;
}
Int64 simplecreator::PackObject::GetLongFieldValue(std::string sFieldName)
{
	PackFieldValue* pFieldValue = GetField(sFieldName);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetLongFieldValue[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return 0;
	}
	if (pFieldValue->FieldType != PackFieldType::Int64Type)
	{
		CCLOGERROR("GetLongFieldValue[0x%04X, %s] fail, field type error = %d", this->GetPackHead(), sFieldName.c_str(), pFieldValue->FieldType);
		return 0;
	}
	return pFieldValue->NormalValue.LongValue;
}

float simplecreator::PackObject::GetFloatFieldValue(std::string sFieldName)
{
	PackFieldValue* pFieldValue = GetField(sFieldName);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetFloatFieldValue[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return 0;
	}
	if (pFieldValue->FieldType != PackFieldType::FloatType)
	{
		CCLOGERROR("GetFloatFieldValue[0x%04X, %s] fail, field type error = %d", this->GetPackHead(), sFieldName.c_str(), pFieldValue->FieldType);
		return 0;
	}
	return pFieldValue->NormalValue.FloatValue;
}

double simplecreator::PackObject::GetDoubleFieldValue(std::string sFieldName)
{
	PackFieldValue* pFieldValue = GetField(sFieldName);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetDoubleFieldValue[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return 0;
	}
	if (pFieldValue->FieldType != PackFieldType::DoubleType)
	{
		CCLOGERROR("GetDoubleFieldValue[0x%04X, %s] fail, field type error = %d", this->GetPackHead(), sFieldName.c_str(), pFieldValue->FieldType);
		return 0;
	}
	return pFieldValue->NormalValue.DoubleValue;
}


std::string simplecreator::PackObject::GetStringFieldValue(std::string sFieldName)
{
	PackFieldValue* pFieldValue = GetField(sFieldName);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetStringFieldValue[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return "";
	}
	if (pFieldValue->FieldType != PackFieldType::StringType)
	{
		CCLOGERROR("GetStringFieldValue[0x%04X, %s] fail, field type error = %d", this->GetPackHead(), sFieldName.c_str(), pFieldValue->FieldType);
		return "";
	}
	return pFieldValue->StringValue;
}

PackObject* simplecreator::PackObject::GetPackFieldValue(std::string sFieldName)
{
	PackFieldValue* pFieldValue = GetField(sFieldName);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetPackFieldValue[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return nullptr;
	}
	if (pFieldValue->FieldType != PackFieldType::PackType)
	{
		CCLOGERROR("GetPackFieldValue[0x%04X, %s] fail, field type error = %d", this->GetPackHead(), sFieldName.c_str(), pFieldValue->FieldType);
		return nullptr;
	}
	return pFieldValue->NormalValue.PackValue;
}

CNetData* simplecreator::PackObject::GetNetDataFieldValue(std::string sFieldName)
{
	PackFieldValue* pFieldValue = GetField(sFieldName);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetNetDataFieldValue[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return nullptr;
	}
	if (pFieldValue->FieldType != PackFieldType::NetDataType)
	{
		CCLOGERROR("GetNetDataFieldValue[0x%04X, %s] fail, field type error = %d", this->GetPackHead(), sFieldName.c_str(), pFieldValue->FieldType);
		return nullptr;
	}
	return pFieldValue->NormalValue.NetDataValue;
}

int simplecreator::PackObject::GetIntFieldValueByIndex(int iFieldIndex)
{
	PackFieldValue* pFieldValue = GetFieldByReadIndex(iFieldIndex);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetIntFieldValueByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return 0;
	}
	if (pFieldValue->FieldType != PackFieldType::UByteType && pFieldValue->FieldType != PackFieldType::UInt16Type
		&& pFieldValue->FieldType != PackFieldType::Int32Type && pFieldValue->FieldType != PackFieldType::Int16Type)
	{
		CCLOGERROR("GetIntFieldValueByIndex[0x%04X, %d] fail, field type error = %d", this->GetPackHead(), iFieldIndex, pFieldValue->FieldType);
		return 0;
	}
	return pFieldValue->NormalValue.IntValue;
}

Int64 simplecreator::PackObject::GetLongFieldValueByIndex(int iFieldIndex)
{
	PackFieldValue* pFieldValue = GetFieldByReadIndex(iFieldIndex);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetIntFieldValueByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return 0;
	}
	if (pFieldValue->FieldType != PackFieldType::Int64Type)
	{
		CCLOGERROR("GetLongFieldValueByIndex[0x%04X, %d] fail, field type error = %d", this->GetPackHead(), iFieldIndex, pFieldValue->FieldType);
		return 0;
	}
	return pFieldValue->NormalValue.LongValue;
}

float simplecreator::PackObject::GetFloatFieldValueByIndex(int iFieldIndex)
{
	PackFieldValue* pFieldValue = GetFieldByReadIndex(iFieldIndex);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetFloatFieldValueByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return 0;
	}
	if (pFieldValue->FieldType != PackFieldType::FloatType)
	{
		CCLOGERROR("GetFloatFieldValueByIndex[0x%04X, %d] fail, field type error = %d", this->GetPackHead(), iFieldIndex, pFieldValue->FieldType);
		return 0;
	}
	return pFieldValue->NormalValue.FloatValue;
}

double simplecreator::PackObject::GetDoubleFieldValueByIndex(int iFieldIndex)
{
	PackFieldValue* pFieldValue = GetFieldByReadIndex(iFieldIndex);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetDoubleFieldValueByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return 0;
	}
	if (pFieldValue->FieldType != PackFieldType::DoubleType)
	{
		CCLOGERROR("GetDoubleFieldValueByIndex[0x%04X, %d] fail, field type error = %d", this->GetPackHead(), iFieldIndex, pFieldValue->FieldType);
		return 0;
	}
	return pFieldValue->NormalValue.DoubleValue;
}

std::string simplecreator::PackObject::GetStringFieldValueByIndex(int iFieldIndex)
{
	PackFieldValue* pFieldValue = GetFieldByReadIndex(iFieldIndex);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetStringFieldValueByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return "";
	}
	if (pFieldValue->FieldType != PackFieldType::StringType)
	{
		CCLOGERROR("GetStringFieldValueByIndex[0x%04X, %d] fail, field type error = %d", this->GetPackHead(), iFieldIndex, pFieldValue->FieldType);
		return "";
	}
	return pFieldValue->StringValue;
}

PackObject* simplecreator::PackObject::GetPackFieldValueByIndex(int iFieldIndex)
{
	PackFieldValue* pFieldValue = GetFieldByReadIndex(iFieldIndex);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetPackFieldValueByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return nullptr;
	}
	if (pFieldValue->FieldType != PackFieldType::PackType)
	{
		CCLOGERROR("GetPackFieldValueByIndex[0x%04X, %d] fail, field type error = %d", this->GetPackHead(), iFieldIndex, pFieldValue->FieldType);
		return nullptr;
	}
	return pFieldValue->NormalValue.PackValue;
}

CNetData* simplecreator::PackObject::GetNetDataFieldValueByIndex(int iFieldIndex)
{
	PackFieldValue* pFieldValue = GetFieldByReadIndex(iFieldIndex);
	if (pFieldValue == nullptr)
	{
		CCLOGERROR("GetNetDataFieldValueByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return nullptr;
	}
	if (pFieldValue->FieldType != PackFieldType::NetDataType)
	{
		CCLOGERROR("GetNetDataFieldValueByIndex[0x%04X, %d] fail, field type error = %d", this->GetPackHead(), iFieldIndex, pFieldValue->FieldType);
		return nullptr;
	}
	return pFieldValue->NormalValue.NetDataValue;
}

std::vector<int> simplecreator::PackObject::GetIntFieldValueListByIndex(int iFieldIndex)
{
	std::vector<int> pValueList;

	PackFieldValueList* pListFieldValue = GetListFieldByReadIndex(iFieldIndex);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("GetIntFieldValueListByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return pValueList;
	}
	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
	{
		pValueList.push_back(pListIter->NormalValue.IntValue);
	}

	return pValueList;
}
std::vector<Int64> simplecreator::PackObject::GetLongFieldValueListByIndex(int iFieldIndex)
{
	std::vector<Int64> pValueList;

	PackFieldValueList* pListFieldValue = GetListFieldByReadIndex(iFieldIndex);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("GetLongFieldValueListByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return pValueList;
	}
	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
	{
		pValueList.push_back(pListIter->NormalValue.LongValue);
	}

	return pValueList;
}

std::vector<float> simplecreator::PackObject::GetFloatFieldValueListByIndex(int iFieldIndex)
{
	std::vector<float> pValueList;

	PackFieldValueList* pListFieldValue = GetListFieldByReadIndex(iFieldIndex);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("GetFloatFieldValueListByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return pValueList;
	}
	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
	{
		pValueList.push_back(pListIter->NormalValue.FloatValue);
	}

	return pValueList;
}

std::vector<double> simplecreator::PackObject::GetDoubleFieldValueListByIndex(int iFieldIndex)
{
	std::vector<double> pValueList;

	PackFieldValueList* pListFieldValue = GetListFieldByReadIndex(iFieldIndex);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("GetFloatFieldValueListByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return pValueList;
	}
	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
	{
		pValueList.push_back(pListIter->NormalValue.DoubleValue);
	}

	return pValueList;
}

std::vector<PackObject*> simplecreator::PackObject::GetPackFieldValueListByIndex(int iFieldIndex)
{
	std::vector<PackObject*> pValueList;

	PackFieldValueList* pListFieldValue = GetListFieldByReadIndex(iFieldIndex);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("GetPackFieldValueListByIndex[0x%04X, %d] fail, no found field", this->GetPackHead(), iFieldIndex);
		return pValueList;
	}

	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
	{
		pValueList.push_back(pListIter->NormalValue.PackValue);
	}

	return pValueList;
}


bool simplecreator::PackObject::InitFieldValueToList(std::string sFieldName, int iFieldIndex, int iArrayCount)
{
	PackFieldValueList* pListFieldValue = GetListFieldByIndex(sFieldName, iFieldIndex, true);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("InitFieldValueToList[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	std::vector<PackFieldValue>* pList = new (std::nothrow) std::vector<PackFieldValue>(iArrayCount);
	if (pList == nullptr)
	{
		CCLOGERROR("InitFieldValueToList[0x%04X, %s] fail, create vector<PackFieldDefine> error", this->GetPackHead(), sFieldName.c_str());
		return false;
	}

	pListFieldValue->ValueList = pList;
	return true;
}

bool simplecreator::PackObject::AddFieldValueToList(std::string sFieldName, int iFieldIndex, int iValueIndex, int iValue)
{
	PackFieldValueList* pListFieldValue = GetListFieldByIndex(sFieldName, iFieldIndex);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, need InitFieldValueToList", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	if (pList == nullptr)
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, need InitFieldValueToList.ValueList", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	if (iValueIndex >= (int)pList->size())
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, iValueIndex[%d] >= pList.size[%d]", this->GetPackHead(), sFieldName.c_str(),
			iValueIndex, (int)pList->size());
		return false;
	}

	NormalPackFieldValue pNormalValue;
	pNormalValue.IntValue = iValue;

	PackFieldValue* pFieldValue = &(*pList)[iValueIndex];

	pFieldValue->FieldType = PackFieldType::Int32Type;
	pFieldValue->NormalValue = pNormalValue;

	return true;
}

bool simplecreator::PackObject::AddFieldValueToList(std::string sFieldName, int iFieldIndex, int iValueIndex, Int64 iValue)
{
	PackFieldValueList* pListFieldValue = GetListFieldByIndex(sFieldName, iFieldIndex);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, need InitFieldValueToList", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	if (pList == nullptr)
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, need InitFieldValueToList.ValueList", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	if (iValueIndex >= (int)pList->size())
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, iValueIndex[%d] >= pList.size[%d]", this->GetPackHead(), sFieldName.c_str(),
			iValueIndex, (int)pList->size());
		return false;
	}

	NormalPackFieldValue pNormalValue;
	pNormalValue.LongValue = iValue;

	PackFieldValue* pFieldValue = &(*pList)[iValueIndex];

	pFieldValue->FieldType = PackFieldType::Int64Type;
	pFieldValue->NormalValue = pNormalValue;

	return true;
}

bool simplecreator::PackObject::AddFieldValueToList(std::string sFieldName, int iFieldIndex, int iValueIndex, float fValue)
{
	PackFieldValueList* pListFieldValue = GetListFieldByIndex(sFieldName, iFieldIndex);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, need InitFieldValueToList", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	if (pList == nullptr)
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, need InitFieldValueToList.ValueList", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	if (iValueIndex >= (int)pList->size())
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, iValueIndex[%d] >= pList.size[%d]", this->GetPackHead(), sFieldName.c_str(),
			iValueIndex, (int)pList->size());
		return false;
	}

	NormalPackFieldValue pNormalValue;
	pNormalValue.FloatValue = fValue;

	PackFieldValue* pFieldValue = &(*pList)[iValueIndex];

	pFieldValue->FieldType = PackFieldType::FloatType;
	pFieldValue->NormalValue = pNormalValue;

	return true;
}

bool simplecreator::PackObject::AddFieldValueToList(std::string sFieldName, int iFieldIndex, int iValueIndex, double fValue)
{
	PackFieldValueList* pListFieldValue = GetListFieldByIndex(sFieldName, iFieldIndex);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, need InitFieldValueToList", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	if (pList == nullptr)
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, need InitFieldValueToList.ValueList", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	if (iValueIndex >= (int)pList->size())
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, iValueIndex[%d] >= pList.size[%d]", this->GetPackHead(), sFieldName.c_str(),
			iValueIndex, (int)pList->size());
		return false;
	}

	NormalPackFieldValue pNormalValue;
	pNormalValue.DoubleValue = fValue;

	PackFieldValue* pFieldValue = &(*pList)[iValueIndex];

	pFieldValue->FieldType = PackFieldType::DoubleType;
	pFieldValue->NormalValue = pNormalValue;

	return true;
}

bool simplecreator::PackObject::AddFieldValueToList(std::string sFieldName, int iFieldIndex, int iValueIndex, PackObject* pValue)
{
	PackFieldValueList* pListFieldValue = GetListFieldByIndex(sFieldName, iFieldIndex);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, need InitFieldValueToList", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	if (pList == nullptr)
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, need InitFieldValueToList.ValueList", this->GetPackHead(), sFieldName.c_str());
		return false;
	}
	if (iValueIndex >= (int)pList->size())
	{
		CCLOGERROR("AddFieldValueToList[0x%04X, %s] fail, iValueIndex[%d] >= pList.size[%d]", this->GetPackHead(), sFieldName.c_str(),
			iValueIndex, (int)pList->size());
		return false;
	}

	NormalPackFieldValue pNormalValue;
	pNormalValue.PackValue = pValue;

	PackFieldValue* pFieldValue = &(*pList)[iValueIndex];

	pFieldValue->FieldType = PackFieldType::PackType;
	pFieldValue->NormalValue = pNormalValue;

	return true;
}


std::vector<int> simplecreator::PackObject::GetIntFieldValueList(std::string sFieldName)
{
	std::vector<int> pValueList;

	PackFieldValueList* pListFieldValue = GetListField(sFieldName);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("GetIntFieldValueList[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return pValueList;
	}

	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
	{
		pValueList.push_back(pListIter->NormalValue.IntValue);
	}

	return pValueList;
}
std::vector<Int64> simplecreator::PackObject::GetLongFieldValueList(std::string sFieldName)
{
	std::vector<Int64> pValueList;

	PackFieldValueList* pListFieldValue = GetListField(sFieldName);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("GetLongFieldValueList[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return pValueList;
	}

	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
	{
		pValueList.push_back(pListIter->NormalValue.LongValue);
	}

	return pValueList;
}

std::vector<float> simplecreator::PackObject::GetFloatFieldValueList(std::string sFieldName)
{
	std::vector<float> pValueList;

	PackFieldValueList* pListFieldValue = GetListField(sFieldName);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("GetFloatFieldValueList[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return pValueList;
	}

	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
	{
		pValueList.push_back(pListIter->NormalValue.FloatValue);
	}

	return pValueList;
}

std::vector<double> simplecreator::PackObject::GetDoubleFieldValueList(std::string sFieldName)
{
	std::vector<double> pValueList;

	PackFieldValueList* pListFieldValue = GetListField(sFieldName);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("GetDoubleFieldValueList[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return pValueList;
	}

	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
	{
		pValueList.push_back(pListIter->NormalValue.DoubleValue);
	}

	return pValueList;
}


std::vector<PackObject*> simplecreator::PackObject::GetPackFieldValueList(std::string sFieldName)
{
	std::vector<PackObject*> pValueList;

	PackFieldValueList* pListFieldValue = GetListField(sFieldName);
	if (pListFieldValue == nullptr)
	{
		CCLOGERROR("GetPackFieldValueList[0x%04X, %s] fail, no found field", this->GetPackHead(), sFieldName.c_str());
		return pValueList;
	}

	std::vector<PackFieldValue>* pList = pListFieldValue->ValueList;
	for (auto pListIter = pList->begin(); pListIter < pList->end(); pListIter++)
	{
		pValueList.push_back(pListIter->NormalValue.PackValue);
	}

	return pValueList;
}


