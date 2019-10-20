#pragma once
#include "Mesh/Flip.h"

namespace Egg { namespace Mesh
{
	GG_CLASS(Multi)
		typedef std::vector<Egg::Mesh::Flip::P> SubmeshVector;
		SubmeshVector submeshes;

	protected:
		Multi(){}
	public:

		void add(Egg::Mesh::Flip::P flip)
		{
			submeshes.push_back(flip);
		}

		Egg::Mesh::Flip::P getSubmesh(unsigned int index)
		{
			//TODO error check
			return submeshes.at(index);
		}

		void draw(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context, Mien mien)
		{
			SubmeshVector::iterator i = submeshes.begin();
			SubmeshVector::iterator e = submeshes.end();
			while(i != e)
			{
				(*i)->draw(context, mien);
				i++;
			}
		}
	GG_ENDCLASS

}} // namespace Egg::Mesh
