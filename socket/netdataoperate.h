#ifndef MEMORY_OPERATE_H
#define MEMORY_OPERATE_H

#include <string>

typedef long long Int64;

namespace simplecreator {

//Buffer��
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

	// ��ѹ�������
	int UnCompress(int iCompressLength, int iSourceLength = 0);
	// ѹ���������
	int Compress();

	//��ȡ����,��ȡ��Ϻ���Ҫɾ������
	int ReadINT32( int &nPos );
	Int64 ReadINT64( int &nPos );
	std::string ReadString( int nLen, int &nPos );

	short ReadINT16(int &nPos);

	//ע�����������ݶ�����ָ��λ��д��
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

	//ָ������д�룬���Ȳ��㲹ȫ0������̫�����ȡ���м�\0�ᱻ��ȡ
	void AddString( const char *pSrcBuf, int nLen );

	//������ݵĳ���
	int GetLength();

	//������ͬ�Ķ���������ֱ������
	void AddObj( const CNetData *pNetData );

	void AddObj( const CNetData *pNetData, int &nPos, int nLen );
private:
	std::string m_strBuffer;
	int m_iRetainCount;
	bool m_bNoDelByClear;
};

}

#endif