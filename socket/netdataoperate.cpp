#include "netdataoperate.h"
#include "zlib.h"
#include "base/CCConsole.h"

using namespace simplecreator;

using std::string;

CNetData::CNetData()
{
	m_strBuffer = "";
	m_iRetainCount = 1;
	m_bNoDelByClear = false;
}

CNetData::~CNetData()
{
	Clear(true);
}



void simplecreator::CNetData::SetNoDelByClear()
{
	m_bNoDelByClear = true;
}

void simplecreator::CNetData::AddRetain()
{
	m_iRetainCount ++;
}

void CNetData::AddBuffer( void *pData, int nLen )
{
	m_strBuffer.append( (char *)pData, nLen );
}

void CNetData::DelBuffer( int nBeginPos, int nLen )
{
	m_strBuffer.erase( nBeginPos, nLen );
}

void CNetData::Clear(bool bDestroy/*=false*/)
{
	if (bDestroy){
		m_strBuffer.clear();
		return;
	}

	m_iRetainCount--;
	if (m_iRetainCount <= 0)
	{
		m_strBuffer.clear();

		if (!m_bNoDelByClear)
		{
			delete this;
		}
	}
}

string &CNetData::GetBuffer()
{
	return m_strBuffer;
}


Int64 simplecreator::CNetData::ReadINT64(int &nPos)
{
	Int64 nResult=*( (Int64*)( &((char *)m_strBuffer.c_str())[nPos] ) );
	nPos+=sizeof(Int64);

	return nResult;
}

int CNetData::ReadINT32( int &nPos )
{
	int nResult=*( (int*)( &((char *)m_strBuffer.c_str())[nPos] ) );
	nPos+=sizeof(int);

	return nResult;
}

short CNetData::ReadINT16( int &nPos )
{
	short nResult=*( (short*)( &((char *)m_strBuffer.c_str())[nPos] ) );
	nPos+=sizeof(short);

	return nResult;
}

string CNetData::ReadString( int nLen, int &nPos )
{
	nPos+=nLen;
	return string( (char *)m_strBuffer.c_str()+nPos-nLen, nLen );
}

void CNetData::AddString( const char* pSrcBuf, int nLen )
{
	string strBuf;
	strBuf.resize(nLen);
	int nSrcLen=(int)strlen(pSrcBuf);
	if( nSrcLen>nLen )
	{
		memcpy( (char*)strBuf.c_str(), pSrcBuf, nLen );
	}
	else
	{
		memcpy( (char *)strBuf.c_str(), pSrcBuf, nSrcLen );
	}


	AddBuffer( (char *)strBuf.c_str(), (int)strBuf.length() );
}
unsigned char CNetData::ReadUBYTE( int &nPos )
{
	unsigned char nResult=*( (unsigned char*)( &((char *)m_strBuffer.c_str())[nPos] ) );
	nPos+=sizeof(unsigned char);

	return nResult;
}
void CNetData::AddUBYTE( unsigned char nValue )
{
	AddBuffer( &nValue, sizeof(nValue) );
}

unsigned short CNetData::ReadUINT16( int &nPos )
{
	unsigned short nResult=*( (unsigned short*)( &((char *)m_strBuffer.c_str())[nPos] ) );
	nPos+=sizeof(unsigned short);

	return nResult;
}

void CNetData::AddUINT16( unsigned short nValue )
{
	AddBuffer( &nValue, sizeof(nValue) );
}

void simplecreator::CNetData::AddINT64(Int64 nValue)
{
	AddBuffer( &nValue, sizeof(nValue) );
}

void CNetData::AddINT32( int nValue )
{
	AddBuffer( &nValue, sizeof(nValue) );
}

void CNetData::AddINT16( short nValue )
{
	AddBuffer( &nValue, sizeof(nValue) );
}

float simplecreator::CNetData::ReadFloat(int &nPos)
{
	float nResult = *( (float*)( &((char *)m_strBuffer.c_str())[nPos] ) );
	nPos += sizeof(float);

	return nResult;
}

void simplecreator::CNetData::AddFloat(float nValue)
{
	AddBuffer( &nValue, sizeof(nValue) );
}

double simplecreator::CNetData::ReadDouble(int &nPos)
{
	double nResult = *( (double*)( &((char *)m_strBuffer.c_str())[nPos] ) );
	nPos += sizeof(double);

	return nResult;
}

void simplecreator::CNetData::AddDouble(double nValue)
{
	AddBuffer( &nValue, sizeof(nValue) );
}

int CNetData::GetLength()
{
	return (int)m_strBuffer.length();
}

void CNetData::AddObj( const CNetData *pNetData )
{
	this->m_strBuffer+=pNetData->m_strBuffer;
}

void simplecreator::CNetData::AddObj(const CNetData *pNetData, int &nPos, int nLen)
{
	this->m_strBuffer.append(pNetData->m_strBuffer.c_str() + nPos, nLen);
}

int simplecreator::CNetData::Compress()
{
	// 当前长度
	uLongf iSourceLen = this->GetLength();
	// 最大压缩长度
	uLongf iCompressLen = compressBound(iSourceLen); 

	Bytef* sBuffer = NULL; 
	if((sBuffer = (Bytef*)malloc(sizeof(Bytef) * iCompressLen)) == NULL)  
	{  
		CCLOG("CNetData.Compress error, malloc memory fail!");  
		return Z_MEM_ERROR;  
	}  

	/* 压缩 */  
	int iErrorCode = compress(sBuffer, &iCompressLen, (const Bytef*)this->m_strBuffer.c_str(), iSourceLen);

	if (iErrorCode != Z_OK)
	{
		CCLOG("CNetData.Compress error, compress error = %d", iErrorCode); 
		return iErrorCode;
	}

	this->m_strBuffer.assign((const char*)sBuffer, iCompressLen);

	return Z_OK;
}

int simplecreator::CNetData::UnCompress(int iCompressLength, int iSourceLength /*= 0*/)
{
	if (iSourceLength <= 0) iSourceLength = iCompressLength * 2;

	Bytef* sBuffer = NULL; 
	if((sBuffer = (Bytef*)malloc(sizeof(Bytef) * iSourceLength)) == NULL)  
	{  
		CCLOG("CNetData.UnCompress error, malloc memory fail!");  
		return Z_MEM_ERROR;  
	}  

	const Bytef* sCompressStr = (const Bytef*)this->m_strBuffer.c_str();

	/* 解压 */  
	uLongf iNewLength = iSourceLength;
	int iErrorCode = uncompress(sBuffer, &iNewLength, sCompressStr, iCompressLength);

	if (iErrorCode == Z_OK)
	{
        this->m_strBuffer.assign((const char*)sBuffer, iNewLength);
        free(sBuffer);
		return Z_OK;
    }
    free(sBuffer);

	// 缓冲区太小
	if (iErrorCode == Z_BUF_ERROR)
	{
		// 扩大缓冲区
		return this->UnCompress(iCompressLength, iSourceLength * 2);
	}

	// 其他错误
	CCLOG("CNetData.UnCompress error, uncompress error = %d", iErrorCode); 
	return iErrorCode;
}
