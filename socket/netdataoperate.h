#ifndef MEMORY_OPERATE_H
#define MEMORY_OPERATE_H

#include <string>

typedef long long Int64;

namespace simplecreator {

//Buffer类
class CNetData
{
public:
	CNetData();

	virtual ~CNetData();

	void AddBuffer( void *pData, int nLen );

	void DelBuffer( int nBeginPos, int nLen );

	void Clear(bool bDestroy=false);
	void SetNoDelByClear();
	void AddRetain();

	std::string &GetBuffer();

	// 解压封包数据
	int UnCompress(int iCompressLength, int iSourceLength = 0);
	// 压缩封包数据
	int Compress();

	//读取数据,读取完毕后需要删除数据
	int ReadINT32( int &nPos );
	Int64 ReadINT64( int &nPos );
	std::string ReadString( int nLen, int &nPos );

	short ReadINT16(int &nPos);

	//注意是增加数据而不是指定位置写入
	void AddINT32( int nValue );
	void AddINT64( Int64 nValue );

	void AddINT16(short nValue);

	unsigned char ReadUBYTE( int &nPos );
	void AddUBYTE( unsigned char nValue );

	float ReadFloat( int &nPos );
	void AddFloat( float nValue );

	double ReadDouble( int &nPos );
	void AddDouble( double nValue );

	unsigned short ReadUINT16( int &nPos );

	void AddUINT16( unsigned short nValue );

	//指定长度写入，长度不足补全0，长度太长则截取，中间\0会被截取
	void AddString( const char *pSrcBuf, int nLen );

	//获得数据的长度
	int GetLength();

	//增加相同的对象，数据流直接增加
	void AddObj( const CNetData *pNetData );

	void AddObj( const CNetData *pNetData, int &nPos, int nLen );
private:
	std::string m_strBuffer;
	int m_iRetainCount;
	bool m_bNoDelByClear;
};

}

#endif