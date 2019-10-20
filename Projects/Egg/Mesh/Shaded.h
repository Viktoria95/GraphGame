#pragma once
#include "Mesh/Geometry.h"
#include "Mesh/Material.h"

namespace Egg { namespace Mesh
{
	GG_CLASS(Shaded)
		Geometry::P geometry;
		Material::P material;
		Microsoft::WRL::ComPtr<ID3D11InputLayout> inputLayout;

	protected:
		Shaded(Geometry::P geometry, Material::P material, Microsoft::WRL::ComPtr<ID3D11InputLayout> inputLayout):geometry(geometry), material(material), inputLayout(inputLayout){}
	public:

		Material::P getMaterial(){return material;}
		Geometry::P getGeometry(){return geometry;}
		Microsoft::WRL::ComPtr<ID3D11InputLayout> getInputLayout(){return inputLayout;}

		void draw(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	GG_ENDCLASS

}} // namespace Egg::Mesh
